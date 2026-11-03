defmodule Lux.Web3.Curve.RebalancerTest do
  @moduledoc false
  use UnitCase, async: true

  alias Lux.Web3.Curve.Rebalancer

  describe "happy path: automated rebalancing" do
    test "plan/3 emits the required deposits and withdrawals" do
      assert {:ok, actions} = Rebalancer.plan(%{a: 1_000, b: 0}, %{a: 5_000, b: 5_000}, 1_000)

      assert actions == [
               %{pool: :a, action: :withdraw, amount: 500},
               %{pool: :b, action: :deposit, amount: 500}
             ]
    end

    test "plan/3 returns no actions when already balanced" do
      assert {:ok, []} = Rebalancer.plan(%{a: 500, b: 500}, %{a: 5_000, b: 5_000}, 1_000)
    end
  end

  describe "null input: handled with a typed validation error" do
    test "plan/3 rejects a null current allocation" do
      assert {:error, :invalid_input} = Rebalancer.plan(nil, %{a: 10_000}, 100)
    end

    test "plan/3 rejects null weights" do
      assert {:error, :invalid_input} = Rebalancer.plan(%{}, nil, 100)
    end
  end

  describe "empty input: rejected with a clear diagnostic" do
    test "plan/3 rejects empty target weights" do
      assert {:error, :empty_target} = Rebalancer.plan(%{}, %{}, 100)
    end

    test "plan/3 rejects empty target weights even with existing positions" do
      assert {:error, :empty_target} = Rebalancer.plan(%{a: 100}, %{}, 100)
    end
  end

  describe "boundary limits: strict half-open evaluation" do
    test "a single unit of total value is allocated at the lower bound" do
      assert {:ok, [%{pool: :a, action: :deposit, amount: 1}]} =
               Rebalancer.plan(%{}, %{a: 10_000}, 1)
    end

    test "weights must sum to exactly 10_000 bps" do
      assert {:error, :invalid_allocation} = Rebalancer.plan(%{}, %{a: 9_999}, 1_000)
    end
  end

  describe "negative: malformed data is refused" do
    test "a non-positive total value is refused" do
      assert {:error, :invalid_total} = Rebalancer.plan(%{}, %{a: 10_000}, 0)
      assert {:error, :invalid_total} = Rebalancer.plan(%{}, %{a: 10_000}, -1)
    end

    test "a negative current position is refused" do
      assert {:error, :invalid_current} = Rebalancer.plan(%{a: -5}, %{a: 10_000}, 1_000)
    end

    test "a negative weight is refused" do
      assert {:error, :invalid_allocation} = Rebalancer.plan(%{}, %{a: -1, b: 10_001}, 1_000)
    end

    test "weights that do not sum to 10_000 are refused" do
      assert {:error, :invalid_allocation} = Rebalancer.plan(%{}, %{a: 20_000}, 1_000)
    end
  end

  describe "concurrency: simultaneous rebalancing plans" do
    test "concurrent plans for the same inputs are identical" do
      results =
        1..20
        |> Enum.map(fn _ ->
          Task.async(fn -> Rebalancer.plan(%{a: 1_000}, %{a: 5_000, b: 5_000}, 1_000) end)
        end)
        |> Task.await_many(30_000)

      assert length(Enum.uniq(results)) == 1
    end
  end
end
