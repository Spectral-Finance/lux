defmodule Lux.Prisms.Coinbase.CoinbaseProductsPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Coinbase.CoinbaseProductsPrism

  describe "input_schema validation" do
    test "has optional product_id" do
      schema = CoinbaseProductsPrism.input_schema()

      assert Map.has_key?(schema.properties, :product_id)
      assert schema.required == []
    end
  end

  describe "output_schema validation" do
    test "requires status and products" do
      schema = CoinbaseProductsPrism.output_schema()

      assert "status" in schema.required
      assert Map.has_key?(schema.properties, :products)
    end
  end
end