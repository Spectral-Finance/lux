defmodule Lux.Prisms.Coinbase.CoinbaseExecuteOrderPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Coinbase.CoinbaseExecuteOrderPrism

  describe "input_schema validation" do
    test "validates required fields" do
      schema = CoinbaseExecuteOrderPrism.input_schema()

      assert "product_id" in schema.required
      assert "side" in schema.required
      assert "order_type" in schema.required
    end

    test "validates side enum" do
      schema = CoinbaseExecuteOrderPrism.input_schema()
      side_property = schema.properties.side

      assert side_property.enum == ["buy", "sell"]
    end

    test "validates order_type enum" do
      schema = CoinbaseExecuteOrderPrism.input_schema()
      order_type_property = schema.properties.order_type

      assert "limit" in order_type_property.enum
      assert "market" in order_type_property.enum
      assert "stop" in order_type_property.enum
      assert "stop_limit" in order_type_property.enum
    end
  end

  describe "output_schema validation" do
    test "requires status field" do
      schema = CoinbaseExecuteOrderPrism.output_schema()

      assert "status" in schema.required
    end
  end

  # Integration tests require Coinbase API credentials
  # Run with: mix test --include integration
  @tag :integration
  describe "handler/2" do
    test "returns error when API key not configured" do
      # This test expects error when credentials are not configured
      result = CoinbaseExecuteOrderPrism.run(%{
        product_id: "BTC-USD",
        side: "buy",
        order_type: "limit",
        price: "50000.00",
        size: "0.01"
      })

      assert {:error, _reason} = result
    end
  end
end