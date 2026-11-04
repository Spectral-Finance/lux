defmodule Lux.Prisms.Hyperliquid.HyperliquidRiskAssessmentPrismTest do
  use UnitCase, async: true

  @moduletag :unit

  alias Lux.Prisms.Hyperliquid.HyperliquidRiskAssessmentPrism

  describe "SCENARIO_HAPPY_PATH (happy_path)" do
    test "validates input schema" do
      prism = HyperliquidRiskAssessmentPrism.view()

      assert prism.input_schema.required == ["portfolio", "market_data", "proposed_trade"]
      assert Map.has_key?(prism.input_schema.properties, :portfolio)
      assert Map.has_key?(prism.input_schema.properties, :market_data)
      assert Map.has_key?(prism.input_schema.properties, :proposed_trade)
    end

    test "validates output schema" do
      prism = HyperliquidRiskAssessmentPrism.view()

      assert prism.output_schema.required == [
               "position_size_ratio",
               "leverage",
               "portfolio_concentration",
               "liquidation_risk",
               "unrealized_pnl"
             ]
    end
  end
end
