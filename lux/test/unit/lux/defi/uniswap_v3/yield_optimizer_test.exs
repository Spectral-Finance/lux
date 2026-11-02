defmodule Lux.Defi.UniswapV3.YieldOptimizerTest do
  use ExUnit.Case, async: true

  alias Lux.Defi.UniswapV3.YieldOptimizer

  describe "calculate_yield/4" do
    test "estimates positive APR and APY for active position" do
      # $10,000 position in pool with $5,000,000 daily volume and 0.3% fee
      result = YieldOptimizer.calculate_yield(10_000.0, 5_000_000.0, 3000)
      assert result.apr_pct > 0.0
      assert result.apy_pct >= result.apr_pct
      assert result.daily_yield_usd > 0.0
    end
  end

  describe "plan_reinvestment/5" do
    test "requires no swap when fees already match target ratio" do
      result = YieldOptimizer.plan_reinvestment(1000, 1000, 1.0, 1.0, 1.0)
      assert result.swap_required == false
      assert result.swap_amount == 0
    end

    test "plans token0 to token1 swap when token0 is in excess" do
      result = YieldOptimizer.plan_reinvestment(2000, 500, 1.0, 1.0, 1.0)
      assert result.swap_required == true
      assert result.swap_direction == :token0_to_token1
      assert result.swap_amount > 0
    end
  end
end
