defmodule Lux.Exchanges.HyperliquidTest do
  use ExUnit.Case, async: true
  alias Lux.Exchanges.Hyperliquid

  test "evaluates long and short perpetual positions, PnL, and liquidation prices" do
    {:ok, long_pos} =
      Hyperliquid.evaluate_perp_position(%{
        entry_price: 2000.0,
        mark_price: 2100.0,
        size: 2.0,
        leverage: 10.0,
        maintenance_margin_ratio: 0.025
      })

    assert long_pos.side == :long
    assert long_pos.unrealized_pnl_usd == 200.0
    assert long_pos.liquidation_price == 1850.0
  end
end
