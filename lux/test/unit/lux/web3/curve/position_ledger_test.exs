defmodule Lux.Web3.Curve.PositionLedgerTest do
  @moduledoc false
  use UnitCase, async: true

  alias Lux.Web3.Curve.PositionLedger

  defp start_ledger(positions) do
    {:ok, ledger} = PositionLedger.start_link(positions)
    on_exit(fn -> if Process.alive?(ledger), do: Agent.stop(ledger) end)
    ledger
  end

  describe "happy path: stablecoin position management" do
    test "deposit/3 and withdraw/3 update the position atomically" do
      ledger = start_ledger(%{three_pool: 1_000})

      assert PositionLedger.balance(ledger, :three_pool) == 1_000
      assert {:ok, 1_100} = PositionLedger.deposit(ledger, :three_pool, 100)
      assert PositionLedger.balance(ledger, :three_pool) == 1_100
      assert {:ok, 1_000} = PositionLedger.withdraw(ledger, :three_pool, 100)
      assert PositionLedger.balance(ledger, :three_pool) == 1_000
    end
  end

  describe "null input: handled with a typed validation error" do
    test "deposit/3 and withdraw/3 reject null amounts" do
      ledger = start_ledger(%{three_pool: 1_000})
      assert {:error, :invalid_amount} = PositionLedger.deposit(ledger, :three_pool, nil)
      assert {:error, :invalid_amount} = PositionLedger.withdraw(ledger, :three_pool, nil)
    end

    test "start_link/1 rejects a null positions map" do
      assert {:error, :invalid_positions} = PositionLedger.start_link(nil)
    end
  end

  describe "empty input: rejected with a clear diagnostic" do
    test "an unknown pool reports a zero balance" do
      ledger = start_ledger(%{})
      assert PositionLedger.balance(ledger, :unknown) == 0
    end

    test "withdrawing from an empty position is refused" do
      ledger = start_ledger(%{})
      assert {:error, :insufficient_position} = PositionLedger.withdraw(ledger, :unknown, 1)
    end
  end

  describe "boundary limits: strict half-open evaluation" do
    test "withdrawing the exact full balance is allowed" do
      ledger = start_ledger(%{three_pool: 1_000})
      assert {:ok, 0} = PositionLedger.withdraw(ledger, :three_pool, 1_000)
      assert PositionLedger.balance(ledger, :three_pool) == 0
    end

    test "withdrawing one unit above the balance is refused" do
      ledger = start_ledger(%{three_pool: 1_000})

      assert {:error, :insufficient_position} =
               PositionLedger.withdraw(ledger, :three_pool, 1_001)

      assert PositionLedger.balance(ledger, :three_pool) == 1_000
    end
  end

  describe "negative: malformed amounts are refused" do
    test "a negative deposit is refused" do
      ledger = start_ledger(%{three_pool: 1_000})
      assert {:error, :invalid_amount} = PositionLedger.deposit(ledger, :three_pool, -1)
      assert PositionLedger.balance(ledger, :three_pool) == 1_000
    end

    test "a negative withdrawal is refused" do
      ledger = start_ledger(%{three_pool: 1_000})
      assert {:error, :invalid_amount} = PositionLedger.withdraw(ledger, :three_pool, -1)
      assert PositionLedger.balance(ledger, :three_pool) == 1_000
    end
  end

  describe "concurrency: atomic transitions with zero double-spend" do
    test "concurrent withdrawals never over-draw the position" do
      ledger = start_ledger(%{three_pool: 1_000})

      results =
        1..20
        |> Enum.map(fn _ ->
          Task.async(fn -> PositionLedger.withdraw(ledger, :three_pool, 100) end)
        end)
        |> Task.await_many(30_000)

      successes = Enum.count(results, &match?({:ok, _}, &1))
      failures = Enum.count(results, &match?({:error, :insufficient_position}, &1))

      assert successes == 10
      assert failures == 10
      assert PositionLedger.balance(ledger, :three_pool) == 0
    end
  end
end
