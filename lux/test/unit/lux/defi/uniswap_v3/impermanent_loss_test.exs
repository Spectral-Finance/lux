defmodule Lux.Defi.UniswapV3.ImpermanentLossTest do
  use ExUnit.Case, async: true

  alias Lux.Defi.UniswapV3.ImpermanentLoss

  describe "standard_il/1" do
    test "returns 0.0 when price ratio is 1.0 (no change)" do
      assert ImpermanentLoss.standard_il(1.0) == 0.0
    end

    test "calculates standard textbook IL values" do
      # For 1.25 (+25% price change), textbook IL is ~ -0.6%
      il = ImpermanentLoss.standard_il(1.25)
      assert_in_delta il, -0.006, 0.002
    end
  end

  describe "concentrated_il/4" do
    test "amplifies IL within concentrated bounds" do
      p_entry = 2000.0
      p_current = 2200.0
      p_lower = 1800.0
      p_upper = 2200.0

      il = ImpermanentLoss.concentrated_il(p_entry, p_current, p_lower, p_upper)
      assert il < 0.0
      assert il >= -1.0
    end
  end

  describe "calculate_net_pnl/3" do
    test "evaluates profitability when fees outweigh IL" do
      # $10,000 capital, 2% IL (-$200), $350 fees earned -> Net +$150
      res = ImpermanentLoss.calculate_net_pnl(10_000.0, -0.02, 350.0)
      assert res.profitable? == true
      assert res.net_pnl_usd == 150.0
      assert res.il_usd == 200.0
    end
  end

  describe "stop_loss_triggered?/5" do
    test "triggers when IL exceeds threshold" do
      # 50% price divergence in narrow range
      assert ImpermanentLoss.stop_loss_triggered?(2000.0, 3000.0, 1900.0, 2100.0, 0.05) == true
      # Zero change
      assert ImpermanentLoss.stop_loss_triggered?(2000.0, 2000.0, 1800.0, 2200.0, 0.05) == false
    end
  end
end
