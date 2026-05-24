defmodule Lux.Prisms.Hyperliquid.HyperliquidMarginManagementPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.Hyperliquid.HyperliquidMarginManagementPrism

  describe "schema validation" do
    test "validates input schema has required fields" do
      prism = HyperliquidMarginManagementPrism.view()

      assert "coin" in prism.input_schema.required
      assert "amount" in prism.input_schema.required
      assert "action" in prism.input_schema.required
    end

    test "validates action property enum" do
      prism = HyperliquidMarginManagementPrism.view()

      action_prop = prism.input_schema.properties.action
      assert action_prop.type == :string
      assert "add" in action_prop.enum
      assert "remove" in action_prop.enum
    end

    test "validates coin property" do
      prism = HyperliquidMarginManagementPrism.view()

      coin_prop = prism.input_schema.properties.coin
      assert coin_prop.type == :string
    end

    test "validates amount property is numeric" do
      prism = HyperliquidMarginManagementPrism.view()

      amount_prop = prism.input_schema.properties.amount
      assert amount_prop.type == :number
    end

    test "validates output schema has required fields" do
      prism = HyperliquidMarginManagementPrism.view()

      assert "status" in prism.output_schema.required
      assert "margin_result" in prism.output_schema.required
    end

    test "validates margin_result schema" do
      prism = HyperliquidMarginManagementPrism.view()

      result_prop = prism.output_schema.properties.margin_result
      assert "coin" in result_prop.required
      assert "action" in result_prop.required
      assert "amount" in result_prop.required
    end
  end
end