defmodule Lux.Prisms.Hyperliquid.HyperliquidLiquidationMonitorPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.Hyperliquid.HyperliquidLiquidationMonitorPrism

  describe "schema validation" do
    test "validates input schema has required address field" do
      prism = HyperliquidLiquidationMonitorPrism.view()

      assert "address" in prism.input_schema.required
    end

    test "validates address property pattern" do
      prism = HyperliquidLiquidationMonitorPrism.view()

      address_prop = prism.input_schema.properties.address
      assert address_prop.type == :string
      assert address_prop.pattern == "^0x[a-fA-F0-9]{40}$"
    end

    test "validates warning_threshold has default" do
      prism = HyperliquidLiquidationMonitorPrism.view()

      warning_prop = prism.input_schema.properties.warning_threshold
      assert warning_prop.type == :number
      assert warning_prop.default == 0.2
    end

    test "validates critical_threshold has default" do
      prism = HyperliquidLiquidationMonitorPrism.view()

      critical_prop = prism.input_schema.properties.critical_threshold
      assert critical_prop.type == :number
      assert critical_prop.default == 0.1
    end

    test "validates output schema has required fields" do
      prism = HyperliquidLiquidationMonitorPrism.view()

      assert "status" in prism.output_schema.required
      assert "positions" in prism.output_schema.required
      assert "summary" in prism.output_schema.required
    end

    test "validates position item has risk_level" do
      prism = HyperliquidLiquidationMonitorPrism.view()

      position_item = prism.output_schema.properties.positions.items
      assert "coin" in position_item.required
      assert "risk_level" in position_item.required
    end

    test "validates summary has count fields" do
      prism = HyperliquidLiquidationMonitorPrism.view()

      summary = prism.output_schema.properties.summary
      assert "total_positions" in summary.required
      assert "safe_count" in summary.required
      assert "warning_count" in summary.required
      assert "critical_count" in summary.required
    end
  end

  describe "risk classification" do
    test "classifies as critical when distance is at or below critical threshold" do
      result =
        HyperliquidLiquidationMonitorPrism.classify_risk(0.05, 0.2, 0.1)

      assert result == "critical"
    end

    test "classifies as critical when distance equals critical threshold" do
      result =
        HyperliquidLiquidationMonitorPrism.classify_risk(0.1, 0.2, 0.1)

      assert result == "critical"
    end

    test "classifies as warning when distance is between critical and warning thresholds" do
      result =
        HyperliquidLiquidationMonitorPrism.classify_risk(0.15, 0.2, 0.1)

      assert result == "warning"
    end

    test "classifies as safe when distance is above warning threshold" do
      result =
        HyperliquidLiquidationMonitorPrism.classify_risk(0.3, 0.2, 0.1)

      assert result == "safe"
    end
  end

  describe "distance calculation" do
    test "returns 1.0 for nil liquidation price" do
      result =
        HyperliquidLiquidationMonitorPrism.calculate_distance(3000.0, "nil", 2800.0)

      assert result == 1.0
    end

    test "calculates correct distance with valid prices" do
      result =
        HyperliquidLiquidationMonitorPrism.calculate_distance(3000.0, "2000", 2800.0)

      # |3000 - 2000| / 3000 = 0.3333
      assert_in_delta result, 0.3333, 0.01
    end

    test "handles very close liquidation price" do
      result =
        HyperliquidLiquidationMonitorPrism.calculate_distance(3000.0, "2950", 2800.0)

      # |3000 - 2950| / 3000 = 0.0167
      assert_in_delta result, 0.0167, 0.01
    end
  end

  describe "summary building" do
    test "builds summary with correct counts" do
      positions = [
        %{"coin" => "ETH", "risk_level" => "safe"},
        %{"coin" => "BTC", "risk_level" => "warning"},
        %{"coin" => "SOL", "risk_level" => "critical"},
        %{"coin" => "ARB", "risk_level" => "safe"}
      ]

      summary = HyperliquidLiquidationMonitorPrism.build_summary(positions)

      assert summary["total_positions"] == 4
      assert summary["safe_count"] == 2
      assert summary["warning_count"] == 1
      assert summary["critical_count"] == 1
    end

    test "handles empty positions list" do
      summary = HyperliquidLiquidationMonitorPrism.build_summary([])

      assert summary["total_positions"] == 0
      assert summary["safe_count"] == 0
      assert summary["warning_count"] == 0
      assert summary["critical_count"] == 0
    end
  end
end