defmodule Lux.Prisms.Hyperliquid.HyperliquidPnLTrackerPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.Hyperliquid.HyperliquidPnLTrackerPrism

  describe "schema validation" do
    test "validates input schema has required address field" do
      prism = HyperliquidPnLTrackerPrism.view()

      assert "address" in prism.input_schema.required
    end

    test "validates address property pattern" do
      prism = HyperliquidPnLTrackerPrism.view()

      address_prop = prism.input_schema.properties.address
      assert address_prop.type == :string
      assert address_prop.pattern == "^0x[a-fA-F0-9]{40}$"
    end

    test "validates output schema has required fields" do
      prism = HyperliquidPnLTrackerPrism.view()

      assert "status" in prism.output_schema.required
      assert "portfolio_summary" in prism.output_schema.required
      assert "position_details" in prism.output_schema.required
    end

    test "validates portfolio_summary has expected metrics" do
      prism = HyperliquidPnLTrackerPrism.view()

      summary = prism.output_schema.properties.portfolio_summary
      assert "total_unrealized_pnl" in summary.required
      assert "account_value" in summary.required
    end

    test "validates position_details item has expected fields" do
      prism = HyperliquidPnLTrackerPrism.view()

      detail_item = prism.output_schema.properties.position_details.items
      assert "coin" in detail_item.required
      assert "unrealized_pnl" in detail_item.required
    end
  end
end