defmodule Lux.Prisms.Hyperliquid.HyperliquidOpenOrdersPrismTest do
  use UnitCase, async: true

  @moduletag :unit

  alias Lux.Prisms.Hyperliquid.HyperliquidOpenOrdersPrism

  describe "SCENARIO_HAPPY_PATH (happy_path)" do
    test "validates input schema" do
      prism = HyperliquidOpenOrdersPrism.view()

      assert prism.input_schema.required == ["address"]
      assert Map.has_key?(prism.input_schema.properties, :address)
    end

    test "validates output schema" do
      prism = HyperliquidOpenOrdersPrism.view()

      assert prism.output_schema.required == ["status", "open_orders"]
    end
  end

  describe "SCENARIO_BOUNDARY (null / empty / boundary)" do
    test "rejects empty input map (no address)" do
      prism = HyperliquidOpenOrdersPrism.view()
      assert "address" in prism.input_schema.required
    end
  end
end
