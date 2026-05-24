defmodule Lux.Prisms.Hyperliquid.HyperliquidExecuteOrderPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.Hyperliquid.HyperliquidExecuteOrderPrism

  describe "schema validation" do
    test "validates input schema has required fields" do
      prism = HyperliquidExecuteOrderPrism.view()

      assert prism.input_schema.required == ["coin", "is_buy", "sz", "limit_px", "order_type"]
    end

    test "validates input schema has optional fields" do
      prism = HyperliquidExecuteOrderPrism.view()

      assert Map.has_key?(prism.input_schema.properties, :reduce_only)
      assert Map.has_key?(prism.input_schema.properties, :vault_address)
    end

    test "validates order_type schema structure" do
      prism = HyperliquidExecuteOrderPrism.view()

      order_type = prism.input_schema.properties.order_type
      assert order_type.type == :object
    end

    test "validates output schema has required fields" do
      prism = HyperliquidExecuteOrderPrism.view()

      assert "status" in prism.output_schema.required
      assert "order_result" in prism.output_schema.required
    end

    test "validates coin property description" do
      prism = HyperliquidExecuteOrderPrism.view()

      coin_prop = prism.input_schema.properties.coin
      assert coin_prop.type == :string
      assert coin_prop.description == "Trading pair symbol (e.g., 'ETH', 'BTC')"
    end

    test "validates sz property is numeric" do
      prism = HyperliquidExecuteOrderPrism.view()

      sz_prop = prism.input_schema.properties.sz
      assert sz_prop.type == :number
    end

    test "validates limit_px property is numeric" do
      prism = HyperliquidExecuteOrderPrism.view()

      limit_px_prop = prism.input_schema.properties.limit_px
      assert limit_px_prop.type == :number
    end

    test "validates is_buy property is boolean" do
      prism = HyperliquidExecuteOrderPrism.view()

      is_buy_prop = prism.input_schema.properties.is_buy
      assert is_buy_prop.type == :boolean
    end

    test "vault_address pattern validation" do
      prism = HyperliquidExecuteOrderPrism.view()

      vault_prop = prism.input_schema.properties.vault_address
      assert vault_prop.pattern == "^0x[a-fA-F0-9]{40}$"
    end
  end
end