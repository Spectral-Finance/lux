defmodule Lux.Prisms.Hyperliquid.HyperliquidRiskAssessmentPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.HyperliquidRiskAssessmentPrism

  describe "schema validation" do
    test "validates input schema has required fields" do
      prism = HyperliquidRiskAssessmentPrism.view()

      assert "portfolio" in prism.input_schema.required
      assert "market_data" in prism.input_schema.required
      assert "proposed_trade" in prism.input_schema.required
    end

    test "validates proposed_trade schema structure" do
      prism = HyperliquidRiskAssessmentPrism.view()

      trade_prop = prism.input_schema.properties.proposed_trade
      assert trade_prop.type == :object
      assert "coin" in trade_prop.required
      assert "sz" in trade_prop.required
      assert "limit_px" in trade_prop.required
      assert "is_buy" in trade_prop.required
    end

    test "validates output schema has all risk metrics" do
      prism = HyperliquidRiskAssessmentPrism.view()

      required = prism.output_schema.required
      assert "position_size_ratio" in required
      assert "leverage" in required
      assert "portfolio_concentration" in required
      assert "liquidation_risk" in required
      assert "unrealized_pnl" in required
    end

    test "validates risk metrics are numeric" do
      prism = HyperliquidRiskAssessmentPrism.view()

      props = prism.output_schema.properties
      assert props.position_size_ratio.type == :number
      assert props.leverage.type == :number
      assert props.portfolio_concentration.type == :number
      assert props.liquidation_risk.type == :number
      assert props.unrealized_pnl.type == :number
    end
  end
end