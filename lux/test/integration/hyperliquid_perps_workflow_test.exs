defmodule Lux.Integration.HyperliquidPerpsWorkflowTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias Lux.Prisms.Hyperliquid.{
    HyperliquidExecuteOrderPrism,
    HyperliquidCancelOrderPrism,
    HyperliquidOpenOrdersPrism,
    HyperliquidTokenInfoPrism,
    HyperliquidUserStatePrism,
    HyperliquidRiskAssessmentPrism,
    HyperliquidSetLeveragePrism,
    HyperliquidMarginManagementPrism,
    HyperliquidLiquidationMonitorPrism,
    HyperliquidPnLTrackerPrism
  }

  alias Lux.Beams.Hyperliquid.TradeRiskManagementBeam

  describe "Hyperliquid perpetual trading workflow" do
    @tag :integration
    test "complete trading workflow: fetch state, assess risk, monitor liquidations" do
      # This integration test validates the full Hyperliquid perp trading workflow
      # Uses the configured test account

      test_address =Application.fetch_env!(:lux, :accounts)[:hyperliquid_address]
      unless test_address != "" do
        flunk("Hyperliquid test address not configured")
      end

      # Step 1: Fetch token market data (no auth needed, read-only)
      {:ok, token_result} = HyperliquidTokenInfoPrism.run(%{})

      assert token_result.prices != nil
      assert is_map(token_result.prices)

      # Verify ETH market data exists
      assert Map.has_key?(token_result.prices, "ETH"),
             "Expected ETH in token prices"

      eth_data = token_result.prices["ETH"]
      assert Map.has_key?(eth_data, "markPx"),
             "Expected markPx in ETH data"

      # Step 2: Fetch user state
      {:ok, user_state} = HyperliquidUserStatePrism.run(%{address: test_address})

      assert user_state.status == "success"
      assert is_map(user_state.user_state)

      # Step 3: Fetch open orders
      {:ok, orders_result} = HyperliquidOpenOrdersPrism.run(%{address: test_address})

      assert orders_result.status == "success"
      assert is_list(orders_result.open_orders)

      # Step 4: Monitor liquidation risk
      {:ok, liq_result} =
        HyperliquidLiquidationMonitorPrism.run(%{
          address: test_address,
          warning_threshold: 0.2,
          critical_threshold: 0.1
        })

      assert liq_result.status == "success"
      assert is_list(liq_result.positions)
      assert is_map(liq_result.summary)
      assert Map.has_key?(liq_result.summary, "total_positions")
      assert Map.has_key?(liq_result.summary, "safe_count")
      assert Map.has_key?(liq_result.summary, "warning_count")
      assert Map.has_key?(liq_result.summary, "critical_count")

      # Step 5: Track PnL
      {:ok, pnl_result} = HyperliquidPnLTrackerPrism.run(%{address: test_address})

      assert pnl_result.status == "success"
      assert is_map(pnl_result.portfolio_summary)
      assert Map.has_key?(pnl_result.portfolio_summary, "total_unrealized_pnl")
      assert Map.has_key?(pnl_result.portfolio_summary, "account_value")
      assert is_list(pnl_result.position_details)
    end

    @tag :integration
    test "risk assessment workflow with market data" do
      test_address = Application.fetch_env!(:lux, :accounts)[:hyperliquid_address]
      unless test_address != "" do
        flunk("Hyperliquid test address not configured")
      end

      # Fetch market data and user state for risk assessment
      {:ok, token_result} = HyperliquidTokenInfoPrism.run(%{})
      {:ok, user_state} = HyperliquidUserStatePrism.run(%{address: test_address})

      # Construct a proposed trade for risk assessment
      proposed_trade = %{
        "coin" => "ETH",
        "sz" => 0.01,
        "limit_px" => String.to_float(token_result.prices["ETH"]["markPx"]),
        "is_buy" => true
      }

      {:ok, risk_result} =
        HyperliquidRiskAssessmentPrism.run(%{
          portfolio: user_state.user_state,
          market_data: token_result.prices,
          proposed_trade: proposed_trade
        })

      assert is_map(risk_result)
      assert Map.has_key?(risk_result, :position_size_ratio) or
               Map.has_key?(risk_result, "position_size_ratio")
      assert Map.has_key?(risk_result, :leverage) or
               Map.has_key?(risk_result, "leverage")
    end
  end
end