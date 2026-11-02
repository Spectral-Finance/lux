defmodule Lux.Trading.Hyperliquid.LiquidationProtectorTest do
  use ExUnit.Case, async: true

  alias Lux.Trading.Hyperliquid.LiquidationProtector

  describe "liquidation_distance_pct/2" do
    test "calculates percentage distance between mark and liquidation price" do
      dist = LiquidationProtector.liquidation_distance_pct(2500.0, 2250.0)
      assert dist == 10.0
    end
  end

  describe "evaluate_risk_tier/1" do
    test "classifies safe position" do
      pos = %{coin: "ETH", mark_px: 3000.0, liquidation_px: 2000.0}
      risk = LiquidationProtector.evaluate_risk_tier(pos)
      assert risk.tier == :safe
      assert risk.action == :none
    end

    test "classifies critical position and recommends emergency close" do
      # 2% distance
      pos = %{coin: "ETH", mark_px: 2040.0, liquidation_px: 2000.0}
      risk = LiquidationProtector.evaluate_risk_tier(pos)
      assert risk.tier == :critical
      assert risk.action == :emergency_close
    end
  end

  describe "plan_derisk/1" do
    test "generates 50% partial close for warning tier" do
      # 5% distance
      pos = %{coin: "ETH", mark_px: 2100.0, liquidation_px: 2000.0, sz: 2.0}
      plan = LiquidationProtector.plan_derisk(pos)
      assert plan.derisk_required? == true
      assert plan.action == :partial_close_50pct
      assert plan.close_size == 1.0
    end
  end
end
