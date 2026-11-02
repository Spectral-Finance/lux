defmodule Lux.Defi.Curve.YieldOptimizerTest do
  use ExUnit.Case, async: true

  alias Lux.Defi.Curve.YieldOptimizer

  describe "calculate_total_apy/4" do
    test "calculates combined base and boosted reward APY" do
      # 2% base APY, 4% CRV APY, 2.5x boost
      result = YieldOptimizer.calculate_total_apy(2.0, 4.0, 2.5, 10_000.0)
      assert result.base_apy_pct == 2.0
      assert result.reward_apy_pct == 10.0
      assert result.total_apy_pct == 12.0
      assert result.annual_projected_usd == 1200.0
    end
  end

  describe "plan_autocompound/3" do
    test "plans reinvestment when viable" do
      # 100 CRV @ $0.50 = $50 (viable)
      res = YieldOptimizer.plan_autocompound(100.0, 0.50, "USDC")
      assert res.viable? == true
      assert res.estimated_lp_return == 50.0

      # 5 CRV @ $0.50 = $2.50 (not viable)
      res_small = YieldOptimizer.plan_autocompound(5.0, 0.50, "USDC")
      assert res_small.viable? == false
    end
  end
end
