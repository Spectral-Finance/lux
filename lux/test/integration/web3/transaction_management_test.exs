defmodule Lux.Web3.TransactionManagementIntegrationTest do
  use IntegrationCase, async: false

  alias Lux.Web3.Gas
  alias Lux.Web3.RPC
  alias Lux.Web3.TransactionBatch
  alias Lux.Web3.TransactionManager

  @moduletag timeout: 30_000

  setup_all do
    {:ok, _} = Application.ensure_all_started(:req)
    executable = System.find_executable("anvil")
    assert executable, "Install Foundry's anvil to run these local-only integration tests"
    {:ok, socket} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, {_, port_number}} = :inet.sockname(socket)
    :ok = :gen_tcp.close(socket)

    port =
      Port.open({:spawn_executable, executable}, [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        args: [
          "--silent",
          "--host",
          "127.0.0.1",
          "--port",
          Integer.to_string(port_number),
          "--hardfork",
          "cancun"
        ]
      ])

    on_exit(fn ->
      case Port.info(port, :os_pid) do
        {:os_pid, pid} -> System.cmd("kill", ["-TERM", Integer.to_string(pid)])
        nil -> :ok
      end
    end)

    options = [rpc_url: "http://127.0.0.1:#{port_number}", timeout: 2_000]
    assert wait_ready(options, 100)
    {:ok, [from | _]} = RPC.request("eth_accounts", [], options)
    fixtures = "test/fixtures/web3/transactions.json" |> File.read!() |> Jason.decode!()
    {:ok, opts: options, from: from, fixtures: fixtures}
  end

  setup %{opts: opts} do
    {:ok, snapshot} = RPC.request("evm_snapshot", [], opts)

    on_exit(fn ->
      RPC.request("evm_setAutomine", [true], opts)
      RPC.request("evm_revert", [snapshot], opts)
    end)

    :ok
  end

  test "preflight obtains real fee history and simulates without changing chain state", ctx do
    counter = deploy(ctx, "CounterFixture")
    tx = %{"from" => ctx.from, "to" => counter, "data" => calldata("increment()")}
    assert {:ok, plan} = TransactionManager.prepare(tx, ctx.opts)
    assert plan.cost.gas_estimate > 21_000
    assert plan.cost.gas_limit >= plan.cost.gas_estimate
    assert plan.cost.maximum_fee_wei >= plan.cost.expected_fee_wei
    assert read_count(counter, ctx.opts) == 0
    assert {:ok, plan} = TransactionManager.prepare(plan.transaction, ctx.opts)
    assert plan.transaction["nonce"] != nil
  end

  test "batch execution consumes less receipt gas than separate transactions with the same result",
       ctx do
    counter = deploy(ctx, "CounterFixture")
    aggregate = deploy(ctx, "AggregateFixture")
    calls = List.duplicate(%{"to" => counter, "data" => calldata("increment()")}, 3)
    options = Keyword.put(ctx.opts, :allow_sender_change, true)

    assert {:ok, %{strategy: :batch, plans: [plan]} = comparison} =
             TransactionManager.plan_batch(calls, ctx.from, aggregate, options)

    assert comparison.gas_saved > 0
    {:ok, snapshot} = RPC.request("evm_snapshot", [], ctx.opts)

    individual_gas =
      Enum.reduce(calls, 0, fn call, acc ->
        assert {:ok, individual} =
                 TransactionManager.prepare(Map.put(call, "from", ctx.from), ctx.opts)

        receipt = send_transaction(individual.transaction, ctx.opts)
        acc + quantity!(receipt["gasUsed"])
      end)

    assert read_count(counter, ctx.opts) == 3
    assert {:ok, true} = RPC.request("evm_revert", [snapshot], ctx.opts)

    receipt = send_transaction(plan.transaction, ctx.opts)
    batch_gas = quantity!(receipt["gasUsed"])
    assert read_count(counter, ctx.opts) == 3
    assert batch_gas < individual_gas

    IO.puts(
      "LOCAL_EVM_GAS individual=#{individual_gas} batch=#{batch_gas} saved=#{individual_gas - batch_gas}"
    )
  end

  test "reverting operations are stopped by real simulation and batches revert atomically", ctx do
    counter = deploy(ctx, "CounterFixture")
    aggregate = deploy(ctx, "AggregateFixture")
    bad = %{"from" => ctx.from, "to" => counter, "data" => calldata("fail()")}
    assert {:error, {:rpc, error}} = TransactionManager.prepare(bad, ctx.opts)
    assert error["message"] =~ "revert"

    calls = [%{"to" => counter, "data" => calldata("increment()")}, Map.delete(bad, "from")]
    assert {:ok, batch} = TransactionBatch.build(calls, aggregate, allow_sender_change: true)

    assert {:error, {:rpc, _}} =
             TransactionManager.prepare(Map.put(batch, "from", ctx.from), ctx.opts)

    assert read_count(counter, ctx.opts) == 0
  end

  for {action, expected_count} <- [speed_up: 1, cancel: 0] do
    test "a real pending transaction can be replaced with #{action}", ctx do
      action = unquote(action)
      counter = deploy(ctx, "CounterFixture")
      tx = %{"from" => ctx.from, "to" => counter, "data" => calldata("increment()")}
      assert {:ok, plan} = TransactionManager.prepare(tx, ctx.opts)
      assert {:ok, _} = RPC.request("evm_setAutomine", [false], ctx.opts)

      assert {:ok, original_hash} =
               RPC.request("eth_sendTransaction", [plan.transaction], ctx.opts)

      assert {:ok, replacement} =
               Gas.replace(plan.transaction, plan.fees.base_fee_per_gas, action)

      assert {:ok, replacement_plan} = TransactionManager.prepare(replacement, ctx.opts)
      assert replacement_plan.transaction["nonce"] == plan.transaction["nonce"]

      assert {:ok, replacement_hash} =
               RPC.request("eth_sendTransaction", [replacement_plan.transaction], ctx.opts)

      assert replacement_hash != original_hash
      assert {:ok, _} = RPC.request("evm_mine", [], ctx.opts)
      receipt = wait_receipt(replacement_hash, ctx.opts)
      assert receipt["status"] == "0x1"
      assert {:ok, nil} = RPC.request("eth_getTransactionReceipt", [original_hash], ctx.opts)
      assert read_count(counter, ctx.opts) == unquote(expected_count)
    end
  end

  test "execute signs with a local unlocked test account and submits the signed bytes once",
       ctx do
    counter = deploy(ctx, "CounterFixture")
    tx = %{"from" => ctx.from, "to" => counter, "data" => calldata("increment()")}
    signer = fn unsigned -> RPC.request("eth_signTransaction", [unsigned], ctx.opts) end
    options = Keyword.put(ctx.opts, :mev_protection, false)
    assert {:ok, %{transaction_hash: hash}} = TransactionManager.execute(tx, signer, options)
    receipt = wait_receipt(hash, ctx.opts)
    assert receipt["status"] == "0x1"
    assert read_count(counter, ctx.opts) == 1
  end

  defp deploy(ctx, name) do
    receipt =
      send_transaction(
        %{"from" => ctx.from, "data" => ctx.fixtures[name], "gas" => "0x989680"},
        ctx.opts
      )

    receipt["contractAddress"]
  end

  defp send_transaction(tx, opts) do
    assert {:ok, hash} = RPC.request("eth_sendTransaction", [tx], opts)
    receipt = wait_receipt(hash, opts)
    assert receipt["status"] == "0x1"
    receipt
  end

  defp wait_receipt(hash, opts, attempts \\ 100)
  defp wait_receipt(_hash, _opts, 0), do: flunk("local transaction was not mined")

  defp wait_receipt(hash, opts, attempts) do
    case RPC.request("eth_getTransactionReceipt", [hash], opts) do
      {:ok, receipt} when is_map(receipt) ->
        receipt

      {:ok, nil} ->
        receive do
        after
          20 -> wait_receipt(hash, opts, attempts - 1)
        end

      error ->
        flunk("receipt request failed: #{inspect(error)}")
    end
  end

  defp calldata(signature), do: signature |> ABI.encode([]) |> Ethers.Utils.hex_encode()

  defp read_count(counter, opts) do
    {:ok, data} =
      RPC.request("eth_call", [%{"to" => counter, "data" => calldata("count()")}, "latest"], opts)

    data |> Ethers.Utils.hex_decode!() |> :binary.decode_unsigned()
  end

  defp quantity!(value) do
    {:ok, number} = Gas.quantity(value)
    number
  end

  defp wait_ready(_opts, 0), do: false

  defp wait_ready(opts, attempts) do
    case RPC.request("eth_chainId", [], opts) do
      {:ok, _} ->
        true

      _ ->
        receive do
        after
          50 -> wait_ready(opts, attempts - 1)
        end
    end
  end
end
