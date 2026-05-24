defmodule Lux.Prisms.Hyperliquid.HyperliquidCancelOrderPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.HyperliquidCancelOrderPrism

  describe "schema validation" do
    test "validates input schema has required fields" do
      prism = HyperliquidCancelOrderPrism.view()

      assert prism.input_schema.required == ["coin", "order_id"]
    end

    test "validates coin property" do
      prism = HyperliquidCancelOrderPrism.view()

      coin_prop = prism.input_schema.properties.coin
      assert coin_prop.type == :string
      assert coin_prop.description == "Trading pair symbol (e.g., 'ETH', 'BTC')"
    end

    test "validates order_id property is integer" do
      prism = HyperliquidCancelOrderPrism.view()

      order_id_prop = prism.input_schema.properties.order_id
      assert order_id_prop.type == :integer
    end

    test "validates output schema has required fields" do
      prism = HyperliquidCancelOrderPrism.view()

      assert "status" in prism.output_schema.required
      assert "cancelled_order" in prism.output_schema.required
    end

    test "validates vault_address is optional" do
      prism = HyperliquidCancelOrderPrism.view()

      vault_prop = prism.input_schema.properties.vault_address
      assert vault_prop.type == :string
      refute "vault_address" in prism.input_schema.required
    end
  end
end