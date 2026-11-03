defmodule Lux.Defi.PancakeSwap.AutocompounderTest do
  use UnitCase, async: true

  alias Lux.Defi.PancakeSwap.Autocompounder

  describe "plan_autocompound/5" do
    test "plans compounding when rewards are viable" do
      # 20 CAKE @ $2.50 = $50. Split into $25 token0 ($2500 ETH @ $2500) and $25 token1 (USDT @ $1.0)
      plan = Autocompounder.plan_autocompound(20.0, 2.50, 2500.0, 1.0, 0.50)

      assert plan.cake_harvested == 20.0
      assert plan.harvest_value_usd == 50.0
      assert plan.token0_amount == 0.01
      assert plan.token1_amount == 25.0
      assert plan.viable? == true
    end

    test "marks unviable when reward is too low" do
      plan = Autocompounder.plan_autocompound(1.0, 2.0, 100.0, 1.0, 0.50)
      # Value = $2.0, below $10.0 threshold
      assert plan.viable? == false
    end

    test "handles zeroes gracefully" do
      plan = Autocompounder.plan_autocompound(0.0, 0.0, 0.0, 0.0)
      assert plan.viable? == false
      assert plan.cake_harvested == 0.0
    end
  end
end
