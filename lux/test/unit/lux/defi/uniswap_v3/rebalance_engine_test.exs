defmodule Lux.Defi.UniswapV3.RebalanceEngineTest do
  use ExUnit.Case, async: true

  alias Lux.Defi.UniswapV3.RebalanceEngine

  setup do
    pos = %{
      token_id: "pos_123",
      token0: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
      token1: "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
      fee: 3000,
      tick_lower: -600,
      tick_upper: 600,
      liquidity: 1_000_000
    }
    %{position: pos}
  end

  describe "needs_rebalance?/3" do
    test "detects optimal position inside center", %{position: pos} do
      assert {:ok, false, :optimal} = RebalanceEngine.needs_rebalance?(pos, 0)
    end

    test "detects out-of-range below", %{position: pos} do
      assert {:ok, true, :out_of_range_below} = RebalanceEngine.needs_rebalance?(pos, -700)
    end

    test "detects out-of-range above", %{position: pos} do
      assert {:ok, true, :out_of_range_above} = RebalanceEngine.needs_rebalance?(pos, 650)
    end

    test "detects boundary approaching", %{position: pos} do
      # 550 is > 85% towards 600
      assert {:ok, true, :approaching_boundary} = RebalanceEngine.needs_rebalance?(pos, 550, 0.85)
    end
  end

  describe "plan_rebalance/4" do
    test "returns hold when optimal", %{position: pos} do
      assert {:ok, plan} = RebalanceEngine.plan_rebalance(pos, 0)
      assert plan.action == :hold
    end

    test "returns rebalance when out of range", %{position: pos} do
      assert {:ok, plan} = RebalanceEngine.plan_rebalance(pos, 800, :moderate)
      assert plan.action == :rebalance
      assert plan.new_tick_lower < 800
      assert plan.new_tick_upper > 800
      assert plan.viable? == true
    end
  end
end
