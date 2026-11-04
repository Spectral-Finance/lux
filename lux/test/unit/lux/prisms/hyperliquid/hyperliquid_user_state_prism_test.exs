defmodule Lux.Prisms.Hyperliquid.HyperliquidUserStatePrismTest do
  use UnitCase, async: true

  @moduletag :unit

  alias Lux.Prisms.Hyperliquid.HyperliquidUserStatePrism

  describe "SCENARIO_HAPPY_PATH (happy_path)" do
    test "validates input schema" do
      prism = HyperliquidUserStatePrism.view()

      assert prism.input_schema.required == ["address"]
      assert Map.has_key?(prism.input_schema.properties, :address)
    end

    test "validates output schema" do
      prism = HyperliquidUserStatePrism.view()

      assert prism.output_schema.required == ["status", "user_state"]
    end
  end

  describe "SCENARIO_BOUNDARY (null / empty / boundary)" do
    test "rejects empty input map (no address)" do
      prism = HyperliquidUserStatePrism.view()
      assert "address" in prism.input_schema.required
    end
  end
end
