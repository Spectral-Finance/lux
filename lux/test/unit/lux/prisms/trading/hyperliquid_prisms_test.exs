defmodule Lux.Prisms.Trading.HyperliquidPrismsTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Trading.Hyperliquid.{
    PlaceOrderPrism,
    ManageMarginPrism,
    TrackPositionsPrism,
    CheckLiquidationRiskPrism,
    AutoDeriskPrism
  }

  describe "PlaceOrderPrism" do
    test "validates and creates order structure" do
      input = %{
        coin: "ETH",
        is_buy: true,
        sz: 0.5,
        limit_px: 2800.0,
        order_type: "limit"
      }

      assert {:ok, res} = PlaceOrderPrism.run(input)
      assert res.coin == "ETH"
      assert res.sz == 0.5
      assert res.status == "open"
      assert is_binary(res.order_id)
    end
  end

  describe "ManageMarginPrism" do
    test "evaluates margin requirements" do
      input = %{
        wallet_balance: 5000.0,
        positions: [
          %{notional: 10000.0, leverage: 10, unrealized_pnl: 250.0}
        ]
      }

      assert {:ok, res} = ManageMarginPrism.run(input)
      assert res.account_equity == 5250.0
      assert res.free_collateral > 0.0
      assert res.margin_call == false
    end
  end

  describe "TrackPositionsPrism" do
    test "tracks position and calculates PnL" do
      input = %{
        coin: "ETH",
        sz: 1.0,
        entry_px: 2500.0,
        mark_px: 2600.0,
        leverage: 10
      }

      assert {:ok, res} = TrackPositionsPrism.run(input)
      assert res.coin == "ETH"
      assert res.direction == "long"
      assert res.unrealized_pnl == 100.0
      assert res.roe_pct > 0.0
    end
  end

  describe "CheckLiquidationRiskPrism" do
    test "evaluates liquidation proximity" do
      input = %{
        position: %{
          coin: "ETH",
          mark_px: 2500.0,
          liquidation_px: 2200.0,
          sz: 1.0
        }
      }

      assert {:ok, res} = CheckLiquidationRiskPrism.run(input)
      assert res.distance_pct == 12.0
      assert res.tier == "moderate"
    end
  end

  describe "AutoDeriskPrism" do
    test "plans emergency close on critical risk" do
      input = %{
        position: %{
          coin: "ETH",
          mark_px: 2040.0,
          liquidation_px: 2000.0,
          sz: 2.0
        }
      }

      assert {:ok, res} = AutoDeriskPrism.run(input)
      assert res.derisk_required == true
      assert res.action == "market_close"
      assert res.close_size == 2.0
    end
  end
end
