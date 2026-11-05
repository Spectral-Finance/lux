defmodule Lux.Web3.Transaction.QueueTest do
  use UnitCase, async: true

  alias Lux.Web3.Transaction
  alias Lux.Web3.Transaction.Queue

  doctest Lux.Web3.Transaction.Queue

  @account "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1"

  setup do
    queue = start_supervised!(Queue)
    %{queue: queue}
  end

  defp build_tx(nonce) do
    {:ok, tx} = Transaction.build(%{chain_id: 1, nonce: nonce, to: @account, value: 1_000})
    tx
  end

  describe "submit/3 and confirm/2 (happy path)" do
    test "queues a transaction and advances the nonce on confirmation", %{queue: queue} do
      assert {:ok, 0} = Queue.next_nonce(queue, @account, 1)

      tx = build_tx(0)
      assert {:ok, id} = Queue.submit(queue, @account, tx)
      assert is_binary(id)

      assert [%{status: :pending, nonce: 0, id: ^id}] = Queue.pending(queue, @account)

      assert {:ok, %{status: :confirmed}} = Queue.confirm(queue, id)
      assert {:ok, 1} = Queue.next_nonce(queue, @account, 1)
      assert [] = Queue.pending(queue, @account)
    end

    test "nonce state is tracked per account and chain", %{queue: queue} do
      assert {:ok, id} = Queue.submit(queue, @account, build_tx(0))
      assert {:ok, %{status: :confirmed}} = Queue.confirm(queue, id)

      assert {:ok, 1} = Queue.next_nonce(queue, @account, 1)
      assert {:ok, 0} = Queue.next_nonce(queue, @account, 137)
      assert {:ok, 0} = Queue.next_nonce(queue, "0x0000000000000000000000000000000000000001", 1)
    end
  end

  describe "submit/3 (null, empty and negative input)" do
    test "rejects a null or malformed account", %{queue: queue} do
      assert {:error, :invalid_account} = Queue.submit(queue, nil, build_tx(0))
      assert {:error, :invalid_account} = Queue.submit(queue, "", build_tx(0))
      assert {:error, :invalid_account} = Queue.submit(queue, "nope", build_tx(0))
    end

    test "rejects a transaction without a usable chain id and nonce", %{queue: queue} do
      assert {:error, :invalid_transaction} = Queue.submit(queue, @account, nil)
      assert {:error, :invalid_transaction} = Queue.submit(queue, @account, %{})

      assert {:error, :invalid_transaction} =
               Queue.submit(queue, @account, %{chain_id: 1, nonce: -1})
    end

    test "rejects a null account and chain for nonce lookup", %{queue: queue} do
      assert {:error, :invalid_account} = Queue.next_nonce(queue, nil, 1)
      assert {:error, :invalid_chain_id} = Queue.next_nonce(queue, @account, nil)
    end
  end

  describe "confirm/2 and fail/2 (negative cases)" do
    test "an unknown transaction cannot be confirmed or failed", %{queue: queue} do
      assert {:error, :unknown_transaction} = Queue.confirm(queue, "0xdead")
      assert {:error, :unknown_transaction} = Queue.fail(queue, "0xdead")
      assert {:error, :unknown_transaction} = Queue.get(queue, "0xdead")
    end

    test "a confirmed transaction cannot be confirmed twice", %{queue: queue} do
      {:ok, id} = Queue.submit(queue, @account, build_tx(0))
      assert {:ok, %{status: :confirmed}} = Queue.confirm(queue, id)
      assert {:error, :not_pending} = Queue.confirm(queue, id)
    end

    test "a failed transaction releases its nonce for retry", %{queue: queue} do
      {:ok, id} = Queue.submit(queue, @account, build_tx(0))
      assert {:ok, %{status: :failed}} = Queue.fail(queue, id)
      assert {:ok, 0} = Queue.next_nonce(queue, @account, 1)

      assert {:ok, _retry} = Queue.submit(queue, @account, build_tx(0))
    end
  end

  describe "submit/3 (boundaries)" do
    test "nonce zero and the expected nonce are both accepted", %{queue: queue} do
      assert {:ok, _} = Queue.submit(queue, @account, build_tx(0))
      assert {:ok, _} = Queue.submit(queue, @account, build_tx(1))
    end

    test "a nonce at or above the expected value is accepted", %{queue: queue} do
      assert {:ok, _} = Queue.submit(queue, @account, build_tx(1_000_000))
    end

    test "a nonce below the expected value is rejected", %{queue: queue} do
      {:ok, id} = Queue.submit(queue, @account, build_tx(0))
      assert {:ok, %{status: :confirmed}} = Queue.confirm(queue, id)

      assert {:error, :nonce_too_low} = Queue.submit(queue, @account, build_tx(0))
    end
  end

  describe "concurrency (atomic nonce reservation)" do
    test "only one of many simultaneous identical submissions wins", %{queue: queue} do
      tx = build_tx(0)

      results =
        1..32
        |> Task.async_stream(fn _ -> Queue.submit(queue, @account, tx) end, max_concurrency: 32)
        |> Enum.map(fn {:ok, result} -> result end)

      accepted = Enum.filter(results, &match?({:ok, _}, &1))
      duplicated = Enum.filter(results, &(&1 == {:error, :duplicate_nonce}))

      assert length(accepted) == 1
      assert length(duplicated) == 31
      assert length(Queue.pending(queue, @account)) == 1
    end

    test "distinct nonces submitted concurrently are each queued exactly once", %{queue: queue} do
      results =
        0..19
        |> Task.async_stream(
          fn nonce -> Queue.submit(queue, @account, build_tx(nonce)) end,
          max_concurrency: 20
        )
        |> Enum.map(fn {:ok, result} -> result end)

      assert Enum.all?(results, &match?({:ok, _}, &1))
      assert length(Queue.pending(queue, @account)) == 20
    end
  end
end
