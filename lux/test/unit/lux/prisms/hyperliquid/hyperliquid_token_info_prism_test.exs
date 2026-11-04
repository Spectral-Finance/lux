defmodule Lux.Prisms.Hyperliquid.HyperliquidTokenInfoPrismTest do
  use UnitCase, async: true

  @moduletag :unit

  alias Lux.Prisms.Hyperliquid.HyperliquidTokenInfoPrism

  describe "SCENARIO_HAPPY_PATH (happy_path)" do
    test "validates input schema (no required fields)" do
      prism = HyperliquidTokenInfoPrism.view()

      assert Map.get(prism.input_schema, :required) == nil
      assert Map.has_key?(prism.output_schema.properties, :prices)
    end

    test "validates output schema" do
      prism = HyperliquidTokenInfoPrism.view()

      assert prism.output_schema.required == ["prices"]
    end
  end
end
