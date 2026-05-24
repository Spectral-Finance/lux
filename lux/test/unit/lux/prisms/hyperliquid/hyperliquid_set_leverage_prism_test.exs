defmodule Lux.Prisms.Hyperliquid.HyperliquidSetLeveragePrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.Hyperliquid.HyperliquidSetLeveragePrism

  describe "schema validation" do
    test "validates input schema has required fields" do
      prism = HyperliquidSetLeveragePrism.view()

      assert "coin" in prism.input_schema.required
      assert "leverage" in prism.input_schema.required
    end

    test "validates coin property" do
      prism = HyperliquidSetLeveragePrism.view()

      coin_prop = prism.input_schema.properties.coin
      assert coin_prop.type == :string
      assert coin_prop.description == "Trading pair symbol (e.g., 'ETH', 'BTC')"
    end

    test "validates leverage property constraints" do
      prism = HyperliquidSetLeveragePrism.view()

      leverage_prop = prism.input_schema.properties.leverage
      assert leverage_prop.type == :integer
      assert leverage_prop.minimum == 1
      assert leverage_prop.maximum == 50
    end

    test "validates is_cross property" do
      prism = HyperliquidSetLeveragePrism.view()

      is_cross_prop = prism.input_schema.properties.is_cross
      assert is_cross_prop.type == :boolean
      assert is_cross_prop.default == true
    end

    test "validates output schema has required fields" do
      prism = HyperliquidSetLeveragePrism.view()

      assert "status" in prism.output_schema.required
      assert "leverage_result" in prism.output_schema.required
    end

    test "validates leverage_result schema" do
      prism = HyperliquidSetLeveragePrism.view()

      result_prop = prism.output_schema.properties.leverage_result
      assert result_prop.type == :object
      assert "coin" in result_prop.required
      assert "leverage" in result_prop.required
      assert "is_cross" in result_prop.required
    end
  end
end