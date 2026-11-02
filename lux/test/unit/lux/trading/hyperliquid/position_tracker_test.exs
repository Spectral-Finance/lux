defmodule Lux.Trading.Hyperliquid.PositionTrackerTest do
  use ExUnit.Case, async: true

  alias Lux.Trading.Hyperliquid.PositionTracker

  describe "track_position/1" do
    test "tracks long position with positive unrealized PnL" do
      params = %{
        coin: "ETH",
        sz: 1.0,
        entry_px: 2500.0,
        mark_px: 2600.0,
        leverage: 10
      }

      assert {:ok, pos} = PositionTracker.track_position(params)
      assert pos.direction == :long
      assert pos.sz == 1.0
      assert pos.notional == 2600.0
      assert pos.unrealized_pnl == 100.0
      assert pos.roe_pct > 0.0
      assert pos.liquidation_px < 2500.0
    end

    test "tracks short position with negative unrealized PnL" do
      params = %{
        coin: "SOL",
        sz: -10.0,
        entry_px: 150.0,
        mark_px: 155.0,
        leverage: 5
      }

      assert {:ok, pos} = PositionTracker.track_position(params)
      assert pos.direction == :short
      assert pos.sz == 10.0
      assert pos.notional == 1550.0
      assert pos.unrealized_pnl == -50.0
      assert pos.roe_pct < 0.0
      assert pos.liquidation_px > 150.0
    end
  end

  describe "update_mark_price/2" do
    test "dynamically updates mark price and recomputes PnL" do
      {:ok, pos} = PositionTracker.track_position(%{coin: "ETH", sz: 1.0, entry_px: 2500.0, mark_px: 2500.0, leverage: 10})
      assert pos.unrealized_pnl == 0.0

      updated = PositionTracker.update_mark_price(pos, 2700.0)
      assert updated.mark_px == 2700.0
      assert updated.unrealized_pnl == 200.0
      assert updated.notional == 2700.0
    end
  end
end
