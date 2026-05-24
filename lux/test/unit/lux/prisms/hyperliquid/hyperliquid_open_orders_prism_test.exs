defmodule Lux.Prisms.Hyperliquid.HyperliquidOpenOrdersPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.HyperliquidOpenOrdersPrism

  describe "schema validation" do
    test "validates input schema has required fields" do
      prism = HyperliquidOpenOrdersPrism.view()

      assert prism.input_schema.required == ["address"]
    end

    test "validates address property" do
      prism = HyperliquidOpenOrdersPrism.view()

      address_prop = prism.input_schema.properties.address
      assert address_prop.type == :string
      assert address_prop.description =~ "Ethereum address"
      assert address_prop.pattern == "^0x[a-fA-F0-9]{40}$"
    end

    test "validates output schema has required fields" do
      prism = HyperliquidOpenOrdersPrism.view()

      assert "status" in prism.output_schema.required
      assert "open_orders" in prism.output_schema.required
    end

    test "validates open_orders is an array" do
      prism = HyperliquidOpenOrdersPrism.view()

      open_orders_prop = prism.output_schema.properties.open_orders
      assert open_orders_prop.type == :array
    end

    test "validates order item schema has required fields" do
      prism = HyperliquidOpenOrdersPrism.view()

      order_item = prism.output_schema.properties.open_orders.items
      assert "coin" in order_item.required
      assert "oid" in order_item.required
      assert "sz" in order_item.required
      assert "limit_px" in order_item.required
    end
  end
end