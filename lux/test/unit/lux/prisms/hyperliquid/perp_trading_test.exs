defmodule Lux.Prisms.Hyperliquid.PerpTradingTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.Hyperliquid.PerpExecutionPrism, as: HL
  alias Lux.Prisms.Hyperliquid.PerpExecutionPrism.{Order, Position}

  describe "Hyperliquid perpetual order and position risk management" do
    test "validates orders and rejects excessive leverage" do
      order = %Order{coin: "ETH", side: :buy, size: 2.5, limit_px: 2500.0}
      assert {:ok, payload} = HL.build_order(order, 10)
      assert payload.coin == "ETH"
      assert payload.is_buy == true
      assert {:error, :excessive_leverage} = HL.build_order(order, 100)
    end

    test "evaluates long position PnL, liquidation price, and protection plan" do
      pos = %Position{
        coin: "SOL",
        side: :long,
        size: 100.0,
        entry_px: 150.0,
        mark_px: 162.0,
        margin_usd: 3000.0,
        leverage: 5
      }

      assert {:ok, metrics} = HL.evaluate_position(pos)
      assert metrics.unrealized_pnl_usd == 1200.0
      assert metrics.risk_status == :healthy
      assert metrics.liquidation_px < 150.0

       distressed = %{pos | mark_px: 121.8, margin_usd: 3000.0}
      assert {:ok, plan} = HL.liquidation_protection_plan(distressed, 2.0)
      assert plan.action == :protect_position
      assert plan.recommended_collateral_add_usd > 0.0
    end
  end
end
