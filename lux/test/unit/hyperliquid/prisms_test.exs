defmodule Lux.Unit.Hyperliquid.PrismsTest do
  @moduledoc """
  Unit tests for Hyperliquid prisms.

  These tests validate prism schemas, handler signatures, and output structures
  without requiring actual Hyperliquid API access.
  """

  use UnitCase, async: true

  alias Lux.Prisms.Hyperliquid.HyperliquidExecuteOrderPrism
  alias Lux.Prisms.Hyperliquid.HyperliquidCancelOrderPrism
  alias Lux.Prisms.Hyperliquid.HyperliquidOpenOrdersPrism
  alias Lux.Prisms.Hyperliquid.HyperliquidRiskAssessmentPrism
  alias Lux.Prisms.Hyperliquid.HyperliquidTokenInfoPrism
  alias Lux.Prisms.Hyperliquid.HyperliquidUserStatePrism
  alias Lux.Prisms.Hyperliquid.HyperliquidPositionManagementPrism
  alias Lux.Prisms.Hyperliquid.HyperliquidMarginManagementPrism

  # ============================================================================
  # HyperliquidExecuteOrderPrism Tests
  # ============================================================================

  describe "HyperliquidExecuteOrderPrism" do
    test "has correct prism metadata" do
      prism = HyperliquidExecuteOrderPrism.view()

      assert prism.name == "Hyperliquid Order Execution"
      assert prism.description == "Executes orders on Hyperliquid exchange"
      assert is_function(prism.handler, 2)
    end

    test "input schema requires correct fields" do
      prism = HyperliquidExecuteOrderPrism.view()

      assert prism.input_schema.required == [
               "coin",
               "is_buy",
               "sz",
               "limit_px",
               "order_type"
             ]

      assert prism.input_schema.properties["coin"].type == :string
      assert prism.input_schema.properties["is_buy"].type == :boolean
      assert prism.input_schema.properties["sz"].type == :number
      assert prism.input_schema.properties["limit_px"].type == :number
    end

    test "input schema supports multiple order types" do
      prism = HyperliquidExecuteOrderPrism.view()

      order_type_schema = prism.input_schema.properties["order_type"]
      assert order_type_schema.oneOf != nil
      assert length(order_type_schema.oneOf) == 3

      # Should support limit, trigger, and slippage order types
      limit_type = Enum.find(order_type_schema.oneOf, fn t ->
        Map.has_key?(t.properties, :limit)
      end)
      assert limit_type != nil

      trigger_type = Enum.find(order_type_schema.oneOf, fn t ->
        Map.has_key?(t.properties, :trigger)
      end)
      assert trigger_type != nil

      slippage_type = Enum.find(order_type_schema.oneOf, fn t ->
        Map.has_key?(t.properties, :slippage)
      end)
      assert slippage_type != nil
    end

    test "input schema supports optional parameters" do
      prism = HyperliquidExecuteOrderPrism.view()

      assert Map.has_key?(prism.input_schema.properties, :reduce_only)
      assert Map.has_key?(prism.input_schema.properties, :vault_address)
      assert Map.has_key?(prism.input_schema.properties, :tp_limit)
      assert Map.has_key?(prism.input_schema.properties, :sl_limit)
    end

    test "output schema has correct structure" do
      prism = HyperliquidExecuteOrderPrism.view()

      assert prism.output_schema.required == ["status", "order_result"]
      assert prism.output_schema.properties["status"].type == :string
      assert prism.output_schema.properties["order_result"].type == :object
    end

    test "limit order type has valid TIF values" do
      prism = HyperliquidExecuteOrderPrism.view()

      limit_type = Enum.find(prism.input_schema.properties["order_type"].oneOf, fn t ->
        Map.has_key?(t.properties, :limit)
      end)

      tif_values = limit_type.properties.limit.properties.tif.enum
      assert tif_values == ["Alo", "Ioc", "Gtc"]
    end

    test "trigger order type has valid TPSL values" do
      prism = HyperliquidExecuteOrderPrism.view()

      trigger_type = Enum.find(prism.input_schema.properties["order_type"].oneOf, fn t ->
        Map.has_key?(t.properties, :trigger)
      end)

      tpsl_values = trigger_type.properties.trigger.properties.tpsl.enum
      assert tpsl_values == ["tp", "sl"]
    end
  end

  # ============================================================================
  # HyperliquidCancelOrderPrism Tests
  # ============================================================================

  describe "HyperliquidCancelOrderPrism" do
    test "has correct prism metadata" do
      prism = HyperliquidCancelOrderPrism.view()

      assert prism.name == "Hyperliquid Order Cancellation"
      assert prism.description == "Cancels orders on Hyperliquid exchange (specific, by coin, or all)"
      assert is_function(prism.handler, 2)
    end

    test "supports multiple cancel actions" do
      prism = HyperliquidCancelOrderPrism.view()

      actions = prism.input_schema.properties["action"].enum
      assert actions == ["cancel", "cancel_all_for_coin", "cancel_all"]
    end

    test "defaults to cancel action" do
      prism = HyperliquidCancelOrderPrism.view()
      assert prism.input_schema.properties["action"].default == "cancel"
    end

    test "output schema supports both single and batch results" do
      prism = HyperliquidCancelOrderPrism.view()

      # Single order cancellation
      assert Map.has_key?(prism.output_schema.properties, :cancelled_order)
      # Batch cancellation
      assert Map.has_key?(prism.output_schema.properties, :cancelled_orders)
    end
  end

  # ============================================================================
  # HyperliquidOpenOrdersPrism Tests
  # ============================================================================

  describe "HyperliquidOpenOrdersPrism" do
    test "has correct prism metadata" do
      prism = HyperliquidOpenOrdersPrism.view()

      assert prism.name == "Hyperliquid Open Orders"
      assert prism.description == "Fetches open orders from Hyperliquid exchange"
    end

    test "input schema requires address" do
      prism = HyperliquidOpenOrdersPrism.view()
      assert prism.input_schema.required == ["address"]
    end

    test "output schema has correct structure" do
      prism = HyperliquidOpenOrdersPrism.view()

      assert prism.output_schema.required == ["status", "open_orders"]
      assert prism.output_schema.properties["open_orders"].type == :array
    end
  end

  # ============================================================================
  # HyperliquidRiskAssessmentPrism Tests
  # ============================================================================

  describe "HyperliquidRiskAssessmentPrism" do
    test "has correct prism metadata" do
      prism = HyperliquidRiskAssessmentPrism.view()

      assert prism.name == "Hyperliquid Risk Assessment"
      assert prism.description == "Calculates risk metrics for a proposed trade"
    end

    test "input schema requires portfolio, market_data, and proposed_trade" do
      prism = HyperliquidRiskAssessmentPrism.view()

      assert prism.input_schema.required == [
               "portfolio",
               "market_data",
               "proposed_trade"
             ]
    end

    test "output schema has all required risk metrics" do
      prism = HyperliquidRiskAssessmentPrism.view()

      assert prism.output_schema.required == [
               "position_size_ratio",
               "leverage",
               "portfolio_concentration",
               "liquidation_risk",
               "unrealized_pnl"
             ]

      assert prism.output_schema.properties["position_size_ratio"].type == :number
      assert prism.output_schema.properties["leverage"].type == :number
      assert prism.output_schema.properties["portfolio_concentration"].type == :number
      assert prism.output_schema.properties["liquidation_risk"].type == :number
      assert prism.output_schema.properties["unrealized_pnl"].type == :number
    end
  end

  # ============================================================================
  # HyperliquidTokenInfoPrism Tests
  # ============================================================================

  describe "HyperliquidTokenInfoPrism" do
    test "has correct prism metadata" do
      prism = HyperliquidTokenInfoPrism.view()

      assert prism.name == "Hyperliquid Token Info"
      assert prism.description == "Fetches token prices from Hyperliquid"
    end

    test "input schema accepts empty input" do
      prism = HyperliquidTokenInfoPrism.view()
      assert prism.input_schema.required == []
    end

    test "output schema has prices structure" do
      prism = HyperliquidTokenInfoPrism.view()

      assert prism.output_schema.required == ["prices"]
      prices_schema = prism.output_schema.properties["prices"]
      assert prices_schema.type == :object
    end

    test "price data schema includes all expected fields" do
      prism = HyperliquidTokenInfoPrism.view()

      price_fields = Map.keys(prism.output_schema.properties["prices"].additionalProperties.properties)
      expected_fields = [
        "funding",
        "openInterest",
        "prevDayPx",
        "dayNtlVlm",
        "premium",
        "oraclePx",
        "markPx",
        "midPx",
        "impactPxs",
        "dayBaseVlm",
        "szDecimals"
      ]

      for field <- expected_fields do
        assert field in price_fields, "Expected field #{field} missing from price schema"
      end
    end
  end

  # ============================================================================
  # HyperliquidUserStatePrism Tests
  # ============================================================================

  describe "HyperliquidUserStatePrism" do
    test "has correct prism metadata" do
      prism = HyperliquidUserStatePrism.view()

      assert prism.name == "Hyperliquid User State"
      assert prism.description == "Fetches user state information from Hyperliquid exchange"
    end

    test "input schema requires address" do
      prism = HyperliquidUserStatePrism.view()
      assert prism.input_schema.required == ["address"]
    end

    test "input schema supports vault_address" do
      prism = HyperliquidUserStatePrism.view()
      assert Map.has_key?(prism.input_schema.properties, :vault_address)
    end

    test "output schema has correct structure" do
      prism = HyperliquidUserStatePrism.view()

      assert prism.output_schema.required == ["status", "user_state"]
      assert prism.output_schema.properties["user_state"].type == :object
    end

    test "user state schema includes position data" do
      prism = HyperliquidUserStatePrism.view()

      user_state_props = prism.output_schema.properties["user_state"].properties
      assert Map.has_key?(user_state_props, :assetPositions)
      assert Map.has_key?(user_state_props, :crossMarginSummary)
    end
  end

  # ============================================================================
  # HyperliquidPositionManagementPrism Tests
  # ============================================================================

  describe "HyperliquidPositionManagementPrism" do
    test "has correct prism metadata" do
      prism = HyperliquidPositionManagementPrism.view()

      assert prism.name == "Hyperliquid Position Management"
      assert prism.description == "Manages existing positions on Hyperliquid exchange"
      assert is_function(prism.handler, 2)
    end

    test "input schema requires action, coin, and address" do
      prism = HyperliquidPositionManagementPrism.view()

      assert prism.input_schema.required == ["action", "coin", "address"]
    end

    test "supports all position management actions" do
      prism = HyperliquidPositionManagementPrism.view()

      actions = prism.input_schema.properties["action"].enum
      expected_actions = [
        "close",
        "partial_close",
        "scale_in",
        "scale_out",
        "trailing_stop",
        "adjust_leverage"
      ]

      for action <- expected_actions do
        assert action in actions, "Expected action #{action} missing"
      end
    end

    test "input schema supports optional parameters" do
      prism = HyperliquidPositionManagementPrism.view()

      assert Map.has_key?(prism.input_schema.properties, :sz)
      assert Map.has_key?(prism.input_schema.properties, :close_percentage)
      assert Map.has_key?(prism.input_schema.properties, :trail_percent)
      assert Map.has_key?(prism.input_schema.properties, :leverage)
      assert Map.has_key?(prism.input_schema.properties, :is_buy)
      assert Map.has_key?(prism.input_schema.properties, :vault_address)
    end

    test "close_percentage constrained to 0.0-1.0" do
      prism = HyperliquidPositionManagementPrism.view()

      assert prism.input_schema.properties["close_percentage"].minimum == 0.0
      assert prism.input_schema.properties["close_percentage"].maximum == 1.0
    end

    test "output schema has correct structure" do
      prism = HyperliquidPositionManagementPrism.view()

      assert prism.output_schema.required == ["status", "action", "coin", "result"]
    end
  end

  # ============================================================================
  # HyperliquidMarginManagementPrism Tests
  # ============================================================================

  describe "HyperliquidMarginManagementPrism" do
    test "has correct prism metadata" do
      prism = HyperliquidMarginManagementPrism.view()

      assert prism.name == "Hyperliquid Margin Management"
      assert prism.description == "Manages margin on Hyperliquid exchange"
      assert is_function(prism.handler, 2)
    end

    test "input schema requires action and address" do
      prism = HyperliquidMarginManagementPrism.view()

      assert prism.input_schema.required == ["action", "address"]
    end

    test "supports all margin management actions" do
      prism = HyperliquidMarginManagementPrism.view()

      actions = prism.input_schema.properties["action"].enum
      expected_actions = [
        "check_margin_health",
        "transfer_margin",
        "get_margin_allocation"
      ]

      for action <- expected_actions do
        assert action in actions, "Expected action #{action} missing"
      end
    end

    test "output schema has correct structure" do
      prism = HyperliquidMarginManagementPrism.view()

      assert prism.output_schema.required == ["status", "action", "result"]
    end
  end

  # ============================================================================
  # Cross-prism consistency tests
  # ============================================================================

  describe "Cross-prism consistency" do
    test "all prisms use consistent address pattern" do
      prisms = [
        HyperliquidExecuteOrderPrism,
        HyperliquidCancelOrderPrism,
        HyperliquidOpenOrdersPrism,
        HyperliquidTokenInfoPrism,
        HyperliquidUserStatePrism,
        HyperliquidPositionManagementPrism,
        HyperliquidMarginManagementPrism
      ]

      address_pattern = "^0x[a-fA-F0-9]{40}$"

      for prism_module <- prisms do
        prism = prism_module.view()
        case prism.input_schema.properties[:address] do
          %{pattern: ^address_pattern} -> :ok
          nil -> :ok  # Some prisms may not have address in input
          _ -> flunk("Prism #{inspect(prism_module)} has inconsistent address pattern")
        end
      end
    end

    test "all prisms with vault_address use consistent pattern" do
      prism_modules = [
        HyperliquidExecuteOrderPrism,
        HyperliquidCancelOrderPrism,
        HyperliquidPositionManagementPrism,
        HyperliquidMarginManagementPrism
      ]

      vault_pattern = "^0x[a-fA-F0-9]{40}$"

      for module <- prism_modules do
        prism = module.view()
        case prism.input_schema.properties[:vault_address] do
          %{pattern: ^vault_pattern} -> :ok
          nil -> flunk("Prism #{inspect(module)} missing vault_address property")
          _ -> flunk("Prism #{inspect(module)} has inconsistent vault_address pattern")
        end
      end
    end
  end
end
