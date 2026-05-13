defmodule Lux.Integrations.Hyperliquid.PerpsTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.Hyperliquid.Perps

  @user_state %{
    "crossMarginSummary" => %{
      "accountValue" => "10000",
      "totalNtlPos" => "20000",
      "totalMarginUsed" => "2500"
    },
    "crossMaintenanceMarginUsed" => "500",
    "withdrawable" => "7500",
    "assetPositions" => [
      %{
        "position" => %{
          "coin" => "ETH",
          "szi" => "2",
          "entryPx" => "2500",
          "positionValue" => "6000",
          "unrealizedPnl" => "1000",
          "returnOnEquity" => "0.2",
          "leverage" => %{"type" => "cross", "value" => 3},
          "liquidationPx" => "2400"
        }
      }
    ]
  }

  describe "position and margin tracking" do
    test "normalizes positions and summarizes margin" do
      assert [%{coin: "ETH", side: :long, size: 2.0, liquidation_price: 2400.0}] =
               Perps.positions(@user_state)

      margin = Perps.margin_summary(@user_state)
      assert margin.account_value == 10000.0
      assert margin.leverage == 2.0
      assert margin.margin_usage == 0.25
      assert margin.maintenance_usage == 0.05
    end

    test "tracks realized and unrealized PnL" do
      pnl = Perps.pnl_tracking(@user_state, [%{"closedPnl" => "125.5"}])

      assert pnl.realized_pnl == 125.5
      assert pnl.unrealized_pnl == 1000.0
      assert pnl.total_pnl == 1125.5
    end
  end

  describe "order_request/1" do
    test "validates order shape for execution prism" do
      assert {:ok, order} =
               Perps.order_request(%{
                 coin: "ETH",
                 is_buy: true,
                 sz: "0.5",
                 limit_px: "3000",
                 order_type: %{limit: %{tif: "Gtc"}}
               })

      assert order.sz == 0.5
      assert order.limit_px == 3000.0

      assert {:error, errors} =
               Perps.order_request(%{coin: "", is_buy: "yes", sz: 0, limit_px: 0})

      assert "coin is required" in errors
      assert "is_buy must be boolean" in errors
    end
  end

  describe "risk controls" do
    test "blocks order when liquidation buffer is too small" do
      assert {:error, decision} =
               Perps.risk_check(
                 @user_state,
                 %{"ETH" => "2500"},
                 %{coin: "ETH", is_buy: true, sz: 0.1, limit_px: 2500}
               )

      assert decision.decision == :blocked
      assert "existing position liquidation buffer is below policy" in decision.alerts
    end

    test "approves small order when policy passes" do
      safer_state =
        put_in(@user_state, ["assetPositions", Access.at(0), "position", "liquidationPx"], "1500")

      assert {:ok, decision} =
               Perps.risk_check(
                 safer_state,
                 %{"ETH" => "3000"},
                 %{coin: "ETH", is_buy: true, sz: 0.1, limit_px: 3000},
                 policy: %{max_leverage: 5.0, max_order_notional_pct: 0.20}
               )

      assert decision.decision == :approved
      assert decision.order_notional == 300.0
    end
  end

  describe "dashboard/2" do
    test "builds compact trading dashboard" do
      dashboard =
        Perps.dashboard(%{
          user_state: @user_state,
          mids: %{"ETH" => "2500"},
          fills: [%{"closedPnl" => "10"}],
          open_orders: [%{"coin" => "ETH"}]
        })

      assert dashboard.margin.account_value == 10000.0
      assert dashboard.pnl.total_pnl == 1010.0
      assert dashboard.open_order_count == 1
      assert dashboard.liquidation.status == :attention_required
    end
  end
end
