defmodule Lux.Integrations.HyperliquidTest do
  use ExUnit.Case
  alias Lux.Integrations.Hyperliquid.Client

  describe "Hyperliquid Order Execution Engine" do
    test "builds valid L1 order struct" do
      order = Client.build_order("ETH", true, 1.5, 3000.0, leverage: 20)
      assert order.asset == "ETH"
      assert order.is_buy == true
      assert order.sz == 1.5
      assert order.limit_px == 3000.0
      assert order.leverage == 20
      assert is_integer(order.timestamp)
    end
  end

  describe "Risk Management & Liquidation Protection" do
    test "calculates liquidation price correctly for long positions" do
      risk = Client.calculate_risk(3000.0, 3100.0, 10, true)
      # 10x leverage = 10% maintenance margin -> Liq price = 3000 - 300 = 2700
      assert risk.liquidation_price == 2700.0
      assert risk.is_at_risk == false
    end

    test "computes unrealized PnL accurately" do
      long_pnl = Client.compute_pnl(3000.0, 3300.0, 2.0, true)
      assert long_pnl == 600.0

      short_pnl = Client.compute_pnl(3000.0, 2800.0, 2.0, false)
      assert short_pnl == 400.0
    end
  end
end
