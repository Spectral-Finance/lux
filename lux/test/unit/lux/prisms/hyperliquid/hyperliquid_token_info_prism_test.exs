defmodule Lux.Prisms.Hyperliquid.HyperliquidTokenInfoPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.HyperliquidTokenInfoPrism

  describe "schema validation" do
    test "input schema accepts empty object" do
      prism = HyperliquidTokenInfoPrism.view()

      assert prism.input_schema.type == :object
      assert prism.input_schema.required == []
      assert prism.input_schema.properties.additionalProperties == false
    end

    test "validates output schema has prices as required" do
      prism = HyperliquidTokenInfoPrism.view()

      assert "prices" in prism.output_schema.required
    end

    test "validates prices is an object with token data" do
      prism = HyperliquidTokenInfoPrism.view()

      prices_prop = prism.output_schema.properties.prices
      assert prices_prop.type == :object
      assert prices_prop.description =~ "token"
    end

    test "validates price item schema has expected fields" do
      prism = HyperliquidTokenInfoPrism.view()

      token_prop = prism.output_schema.properties.prices.additionalProperties
      assert Map.has_key?(token_prop.properties, :funding)
      assert Map.has_key?(token_prop.properties, :markPx)
      assert Map.has_key?(token_prop.properties, :openInterest)
      assert Map.has_key?(token_prop.properties, :szDecimals)
    end
  end
end