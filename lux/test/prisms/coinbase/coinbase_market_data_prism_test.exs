defmodule Lux.Prisms.Coinbase.CoinbaseMarketDataPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Coinbase.CoinbaseMarketDataPrism

  describe "input_schema validation" do
    test "validates required fields" do
      schema = CoinbaseMarketDataPrism.input_schema()

      assert "product_id" in schema.required
      assert "data_type" in schema.required
    end

    test "validates data_type enum" do
      schema = CoinbaseMarketDataPrism.input_schema()
      data_type_property = schema.properties.data_type

      assert "ticker" in data_type_property.enum
      assert "orderbook" in data_type_property.enum
      assert "trades" in data_type_property.enum
      assert "candles" in data_type_property.enum
      assert "product" in data_type_property.enum
    end

    test "validates level constraints" do
      schema = CoinbaseMarketDataPrism.input_schema()
      level_property = schema.properties.level

      assert level_property.minimum == 1
      assert level_property.maximum == 3
    end

    test "validates granularity enum" do
      schema = CoinbaseMarketDataPrism.input_schema()
      granularity_property = schema.properties.granularity

      assert 60 in granularity_property.enum
      assert 300 in granularity_property.enum
      assert 900 in granularity_property.enum
      assert 3600 in granularity_property.enum
      assert 21600 in granularity_property.enum
      assert 86400 in granularity_property.enum
    end
  end

  describe "output_schema validation" do
    test "requires status" do
      schema = CoinbaseMarketDataPrism.output_schema()

      assert "status" in schema.required
    end
  end
end