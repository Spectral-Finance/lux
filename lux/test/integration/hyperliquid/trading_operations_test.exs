defmodule Lux.Integration.Hyperliquid.TradingOperationsTest do
  @moduledoc """
  Integration tests for Hyperliquid trading operations.

  These tests require actual Hyperliquid API credentials to run.
  They validate the full trading pipeline: order execution, position management,
  risk assessment, and margin management.

  Run with:
      HYPERLIQUID_PRIVATE_KEY=xxx HYPERLIQUID_ADDRESS=xxx HYPERLIQUID_API_URL=xxx mix test test/integration/hyperliquid/trading_operations_test.exs
  """

  use IntegrationCase

  alias Lux.Prisms.Hyperliquid.HyperliquidExecuteOrderPrism
  alias Lux.Prisms.Hyperliquid.HyperliquidCancelOrderPrism
  alias Lux.Prisms.Hyperliquid.HyperliquidOpenOrdersPrism
  alias Lux.Prisms.Hyperliquid.HyperliquidRiskAssessmentPrism
  alias Lux.Prisms.Hyperliquid.HyperliquidTokenInfoPrism
  alias Lux.Prisms.Hyperliquid.HyperliquidUserStatePrism
  alias Lux.Prisms.Hyperliquid.HyperliquidPositionManagementPrism
  alias Lux.Prisms.Hyperliquid.HyperliquidMarginManagementPrism
  alias Lux.Beams.Hyperliquid.TradeRiskManagementBeam

  @moduletag :integration

  # ============================================================================
  # Token Info Tests
  # ============================================================================

  describe "HyperliquidTokenInfoPrism" do
    test "fetches token prices successfully" do
      {:ok, result} = HyperliquidTokenInfoPrism.run(%{})

      assert result["prices"] != nil
      # ETH and BTC should always be available on Hyperliquid
      assert result["prices"]["ETH"] != nil
      assert result["prices"]["BTC"] != nil

      eth_data = result["prices"]["ETH"]
      assert eth_data["markPx"] != nil
      assert eth_data["funding"] != nil
    end

    test "returns price data for multiple tokens" do
      {:ok, result} = HyperliquidTokenInfoPrism.run(%{})

      prices = result["prices"]
      assert is_map(prices)
      assert map_size(prices) > 5
    end
  end

  # ============================================================================
  # User State Tests
  # ============================================================================

  describe "HyperliquidUserStatePrism" do
    test "fetches user state for a valid address" do
      address = System.get_env("HYPERLIQUID_ADDRESS", "")

      skip unless address != "" and byte_size(address) > 0

      {:ok, result} =
        HyperliquidUserStatePrism.run(%{
          address: address
        })

      assert result["user_state"] != nil
      user_state = result["user_state"]

      # User state should contain expected fields
      assert Map.has_key?(user_state, "assetPositions")
      assert Map.has_key?(user_state, "crossMarginSummary")
    end

    test "handles vault_address parameter" do
      address = System.get_env("HYPERLIQUID_ADDRESS", "")
      vault = "0x0403369c02199a0cb827f4d6492927e9fa5668d5"

      skip unless address != "" and byte_size(address) > 0

      {:ok, result} =
        HyperliquidUserStatePrism.run(%{
          address: address,
          vault_address: vault
        })

      assert result["status"] == "success"
      assert result["user_state"] != nil
    end
  end

  # ============================================================================
  # Open Orders Tests
  # ============================================================================

  describe "HyperliquidOpenOrdersPrism" do
    test "fetches open orders for a valid address" do
      address = System.get_env("HYPERLIQUID_ADDRESS", "")

      skip unless address != "" and byte_size(address) > 0

      {:ok, result} =
        HyperliquidOpenOrdersPrism.run(%{
          address: address
        })

      assert result["status"] == "success"
      assert is_list(result["open_orders"])
    end
  end

  # ============================================================================
  # Risk Assessment Tests
  # ============================================================================

  describe "HyperliquidRiskAssessmentPrism" do
    test "calculates risk metrics for a proposed trade" do
      address = System.get_env("HYPERLIQUID_ADDRESS", "")

      skip unless address != "" and byte_size(address) > 0

      # Fetch real portfolio and market data first
      {:ok, state_result} =
        HyperliquidUserStatePrism.run(%{address: address})

      {:ok, price_result} = HyperliquidTokenInfoPrism.run(%{})

      portfolio = state_result["user_state"]
      market_data = price_result["prices"]

      proposed_trade = %{
        coin: "ETH",
        sz: 0.1,
        limit_px: 2800.0,
        is_buy: true
      }

      {:ok, risk_metrics} =
        HyperliquidRiskAssessmentPrism.run(%{
          portfolio: portfolio,
          market_data: market_data,
          proposed_trade: proposed_trade
        })

      # Verify risk metrics structure
      assert risk_metrics["position_size_ratio"] != nil
      assert risk_metrics["leverage"] != nil
      assert risk_metrics["portfolio_concentration"] != nil
      assert risk_metrics["liquidation_risk"] != nil
      assert risk_metrics["unrealized_pnl"] != nil

      # Leverage should be a reasonable number
      assert risk_metrics["leverage"] >= 0
    end
  end

  # ============================================================================
  # Order Execution Tests
  # ============================================================================

  describe "HyperliquidExecuteOrderPrism" do
    test "limit order execution with proper schema" do
      address = System.get_env("HYPERLIQUID_ADDRESS", "")

      skip unless address != "" and byte_size(address) > 0

      # Fetch current price for realistic order
      {:ok, price_result} = HyperliquidTokenInfoPrism.run(%{})
      eth_price = Float.parse(price_result["prices"]["ETH"]["markPx"]) |> elem(0)

      # Place a very small test order with reduce_only to minimize risk
      {:ok, result} =
        HyperliquidExecuteOrderPrism.run(%{
          coin: "ETH",
          is_buy: true,
          sz: 0.001,
          limit_px: eth_price * 0.99,
          order_type: %{limit: %{tif: "Gtc"}},
          reduce_only: false
        })

      assert result["status"] == "success"
      assert result["order_result"] != nil
    end

    test "slippage-controlled order execution" do
      address = System.get_env("HYPERLIQUID_ADDRESS", "")

      skip unless address != "" and byte_size(address) > 0

      {:ok, result} =
        HyperliquidExecuteOrderPrism.run(%{
          coin: "ETH",
          is_buy: true,
          sz: 0.001,
          limit_px: 2800.0,
          order_type: %{slippage: 0.5},
          reduce_only: false
        })

      assert result["status"] == "success"
      # Slippage orders return enhanced result with effective price
      assert result["order_result"]["effective_px"] != nil
      assert result["order_result"]["slippage_pct"] == 0.5
    end

    test "trigger order (stop loss)" do
      address = System.get_env("HYPERLIQUID_ADDRESS", "")

      skip unless address != "" and byte_size(address) > 0

      {:ok, price_result} = HyperliquidTokenInfoPrism.run(%{})
      eth_price = Float.parse(price_result["prices"]["ETH"]["markPx"]) |> elem(0)

      {:ok, result} =
        HyperliquidExecuteOrderPrism.run(%{
          coin: "ETH",
          is_buy: false,
          sz: 0.001,
          limit_px: eth_price,
          order_type: %{
            trigger: %{
              triggerPx: eth_price * 0.95,
              isMarket: true,
              tpsl: "sl"
            }
          },
          reduce_only: true
        })

      assert result["status"] == "success"
    end

    test "order with vault_address" do
      address = System.get_env("HYPERLIQUID_ADDRESS", "")
      vault = "0x0403369c02199a0cb827f4d6492927e9fa5668d5"

      skip unless address != "" and byte_size(address) > 0

      {:ok, result} =
        HyperliquidExecuteOrderPrism.run(%{
          coin: "ETH",
          is_buy: true,
          sz: 0.001,
          limit_px: 2800.0,
          order_type: %{limit: %{tif: "Gtc"}},
          vault_address: vault
        })

      assert result["status"] == "success"
    end

    test "order with take-profit and stop-loss limits" do
      address = System.get_env("HYPERLIQUID_ADDRESS", "")

      skip unless address != "" and byte_size(address) > 0

      {:ok, price_result} = HyperliquidTokenInfoPrism.run(%{})
      eth_price = Float.parse(price_result["prices"]["ETH"]["markPx"]) |> elem(0)

      {:ok, result} =
        HyperliquidExecuteOrderPrism.run(%{
          coin: "ETH",
          is_buy: true,
          sz: 0.001,
          limit_px: eth_price,
          order_type: %{limit: %{tif: "Gtc"}},
          tp_limit: %{
            limit_px: eth_price * 1.05,
            sz: 0.001
          },
          sl_limit: %{
            limit_px: eth_price * 0.95,
            sz: 0.001
          }
        })

      assert result["status"] == "success"
    end
  end

  # ============================================================================
  # Cancel Order Tests
  # ============================================================================

  describe "HyperliquidCancelOrderPrism" do
    test "cancel all orders for a coin" do
      address = System.get_env("HYPERLIQUID_ADDRESS", "")

      skip unless address != "" and byte_size(address) > 0

      {:ok, result} =
        HyperliquidCancelOrderPrism.run(%{
          action: "cancel_all_for_coin",
          coin: "ETH",
          address: address
        })

      assert result["status"] == "success"
      assert is_list(result["cancelled_orders"])
    end

    test "cancel all orders" do
      address = System.get_env("HYPERLIQUID_ADDRESS", "")

      skip unless address != "" and byte_size(address) > 0

      {:ok, result} =
        HyperliquidCancelOrderPrism.run(%{
          action: "cancel_all",
          address: address
        })

      assert result["status"] == "success"
      assert is_list(result["cancelled_orders"])
    end
  end

  # ============================================================================
  # Position Management Tests
  # ============================================================================

  describe "HyperliquidPositionManagementPrism" do
    test "check position for a coin with no position" do
      address = System.get_env("HYPERLIQUID_ADDRESS", "")

      skip unless address != "" and byte_size(address) > 0

      # Try to close a position that doesn't exist
      {:ok, result} =
        HyperliquidPositionManagementPrism.run(%{
          action: "close",
          coin: "ETH",
          address: address
        })

      # Should return no_position status gracefully
      assert result["status"] == "success"
      assert result["result"]["status"] in ["no_position", "closed"]
    end

    test "partial close with percentage" do
      address = System.get_env("HYPERLIQUID_ADDRESS", "")

      skip unless address != "" and byte_size(address) > 0

      {:ok, result} =
        HyperliquidPositionManagementPrism.run(%{
          action: "partial_close",
          coin: "ETH",
          close_percentage: 0.5,
          address: address
        })

      assert result["status"] == "success"
      assert result["action"] == "partial_close"
    end

    test "trailing stop order" do
      address = System.get_env("HYPERLIQUID_ADDRESS", "")

      skip unless address != "" and byte_size(address) > 0

      {:ok, result} =
        HyperliquidPositionManagementPrism.run(%{
          action: "trailing_stop",
          coin: "ETH",
          trail_percent: 5.0,
          address: address
        })

      assert result["status"] == "success"
    end

    test "scale in operation" do
      address = System.get_env("HYPERLIQUID_ADDRESS", "")

      skip unless address != "" and byte_size(address) > 0

      {:ok, result} =
        HyperliquidPositionManagementPrism.run(%{
          action: "scale_in",
          coin: "ETH",
          sz: 0.001,
          is_buy: true,
          address: address
        })

      assert result["status"] == "success"
    end
  end

  # ============================================================================
  # Margin Management Tests
  # ============================================================================

  describe "HyperliquidMarginManagementPrism" do
    test "check margin health" do
      address = System.get_env("HYPERLIQUID_ADDRESS", "")

      skip unless address != "" and byte_size(address) > 0

      {:ok, result} =
        HyperliquidMarginManagementPrism.run(%{
          action: "check_margin_health",
          address: address
        })

      assert result["status"] == "success"
      assert result["result"]["health_status"] != nil
      assert result["result"]["account_value"] != nil
      assert result["result"]["margin_utilization"] != nil
    end

    test "get margin allocation" do
      address = System.get_env("HYPERLIQUID_ADDRESS", "")

      skip unless address != "" and byte_size(address) > 0

      {:ok, result} =
        HyperliquidMarginManagementPrism.run(%{
          action: "get_margin_allocation",
          address: address
        })

      assert result["status"] == "success"
      assert result["result"]["total_account_value"] != nil
      assert result["result"]["allocations"] != nil
      assert is_list(result["result"]["allocations"])
    end

    test "transfer margin to position" do
      address = System.get_env("HYPERLIQUID_ADDRESS", "")

      skip unless address != "" and byte_size(address) > 0

      {:ok, result} =
        HyperliquidMarginManagementPrism.run(%{
          action: "transfer_margin",
          coin: "ETH",
          margin_usd: 100.0,
          address: address
        })

      assert result["status"] == "success"
    end
  end

  # ============================================================================
  # Trade Risk Management Beam Tests
  # ============================================================================

  describe "TradeRiskManagementBeam" do
    test "executes a trade through the risk management pipeline" do
      address = System.get_env("HYPERLIQUID_ADDRESS", "")

      skip unless address != "" and byte_size(address) > 0

      {:ok, price_result} = HyperliquidTokenInfoPrism.run(%{})
      eth_price = Float.parse(price_result["prices"]["ETH"]["markPx"]) |> elem(0)

      trade = %{
        coin: "ETH",
        is_buy: true,
        sz: 0.001,
        limit_px: eth_price,
        order_type: %{limit: %{tif: "Gtc"}},
        reduce_only: false
      }

      {:ok, result} =
        TradeRiskManagementBeam.run(%{
          address: address,
          trade: trade
        })

      assert result["status"] in ["success", "rejected"]
      assert result["order_result"] != nil
    end
  end

  # ============================================================================
  # Schema Validation Tests
  # ============================================================================

  describe "Prism schema validation" do
    test "HyperliquidExecuteOrderPrism has valid input schema" do
      prism = HyperliquidExecuteOrderPrism.view()
      assert prism.input_schema.required == ["coin", "is_buy", "sz", "limit_px", "order_type"]
      assert prism.input_schema.properties["coin"].type == :string
      assert prism.input_schema.properties["is_buy"].type == :boolean
      assert prism.input_schema.properties["sz"].type == :number
    end

    test "HyperliquidPositionManagementPrism has valid input schema" do
      prism = HyperliquidPositionManagementPrism.view()
      assert prism.input_schema.required == ["action", "coin", "address"]
      assert prism.input_schema.properties["action"].enum == [
               "close",
               "partial_close",
               "scale_in",
               "scale_out",
               "trailing_stop",
               "adjust_leverage"
             ]
    end

    test "HyperliquidMarginManagementPrism has valid input schema" do
      prism = HyperliquidMarginManagementPrism.view()
      assert prism.input_schema.required == ["action", "address"]
      assert prism.input_schema.properties["action"].enum == [
               "check_margin_health",
               "transfer_margin",
               "get_margin_allocation"
             ]
    end

    test "HyperliquidCancelOrderPrism supports batch actions" do
      prism = HyperliquidCancelOrderPrism.view()
      assert prism.input_schema.properties["action"].enum == [
               "cancel",
               "cancel_all_for_coin",
               "cancel_all"
             ]
    end

    test "HyperliquidUserStatePrism supports vault_address" do
      prism = HyperliquidUserStatePrism.view()
      assert Map.has_key?(prism.input_schema.properties, :vault_address)
    end
  end

  # ============================================================================
  # Error Handling Tests
  # ============================================================================

  describe "Error handling" do
    test "execute order with invalid coin returns error" do
      address = System.get_env("HYPERLIQUID_ADDRESS", "")

      skip unless address != "" and byte_size(address) > 0

      {:error, reason} =
        HyperliquidExecuteOrderPrism.run(%{
          coin: "INVALIDCOIN",
          is_buy: true,
          sz: 0.001,
          limit_px: 100.0,
          order_type: %{limit: %{tif: "Gtc"}}
        })

      # Should return an error, not crash
      assert is_binary(reason) or is_map(reason)
    end

    test "position management with nonexistent coin" do
      {:ok, result} =
        HyperliquidPositionManagementPrism.run(%{
          action: "close",
          coin: "NONEXISTENTCOIN",
          address: "0x0000000000000000000000000000000000000000"
        })

      # Should handle gracefully
      assert result["status"] == "success"
    end
  end
end
