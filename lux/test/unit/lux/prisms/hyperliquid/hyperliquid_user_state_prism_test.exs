defmodule Lux.Prisms.Hyperliquid.HyperliquidUserStatePrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.Hyperliquid.HyperliquidUserStatePrism

  describe "schema validation" do
    test "validates input schema has required address field" do
      prism = HyperliquidUserStatePrism.view()

      assert prism.input_schema.required == ["address"]
    end

    test "validates address property" do
      prism = HyperliquidUserStatePrism.view()

      address_prop = prism.input_schema.properties.address
      assert address_prop.type == :string
      assert address_prop.pattern == "^0x[a-fA-F0-9]{40}$"
    end

    test "validates output schema has required fields" do
      prism = HyperliquidUserStatePrism.view()

      assert "status" in prism.output_schema.required
      assert "user_state" in prism.output_schema.required
    end

    test "validates user_state contains assetPositions" do
      prism = HyperliquidUserStatePrism.view()

      user_state = prism.output_schema.properties.user_state
      assert Map.has_key?(user_state.properties, :assetPositions)
      assert user_state.properties.assetPositions.type == :array
    end

    test "validates user_state contains crossMarginSummary" do
      prism = HyperliquidUserStatePrism.view()

      user_state = prism.output_schema.properties.user_state
      assert Map.has_key?(user_state.properties, :crossMarginSummary)
    end

    test "validates position item has expected fields" do
      prism = HyperliquidUserStatePrism.view()

      position_item = prism.output_schema.properties.user_state.properties.assetPositions.items
      pos_props = position_item.properties.position.properties

      assert Map.has_key?(pos_props, :entryPx)
      assert Map.has_key?(pos_props, :leverage)
      assert Map.has_key?(pos_props, :liquidationPx)
      assert Map.has_key?(pos_props, :marginUsed)
      assert Map.has_key?(pos_props, :positionValue)
      assert Map.has_key?(pos_props, :returnOnEquity)
      assert Map.has_key?(pos_props, :size)
    end
  end
end