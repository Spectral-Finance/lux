defmodule Lux.Prisms.Coinbase.CoinbaseCancelOrderPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Coinbase.CoinbaseCancelOrderPrism

  describe "input_schema validation" do
    test "has correct schema structure" do
      schema = CoinbaseCancelOrderPrism.input_schema()

      assert schema.type == :object
      assert Map.has_key?(schema.properties, :order_id)
      assert Map.has_key?(schema.properties, :cancel_all)
      assert Map.has_key?(schema.properties, :product_id)
    end
  end

  describe "output_schema validation" do
    test "requires status field" do
      schema = CoinbaseCancelOrderPrism.output_schema()

      assert "status" in schema.required
      assert Map.has_key?(schema.properties, :cancelled_orders)
    end
  end

  # Integration tests require Coinbase API credentials
  @tag :integration
  describe "handler/2" do
    test "returns error when API key not configured" do
      result = CoinbaseCancelOrderPrism.run(%{order_id: "test_order_id"})

      assert {:error, _reason} = result
    end
  end
end