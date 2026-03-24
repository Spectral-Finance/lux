defmodule Lux.Prisms.Coinbase.CoinbaseOpenOrdersPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Coinbase.CoinbaseOpenOrdersPrism

  describe "input_schema validation" do
    test "has optional filters" do
      schema = CoinbaseOpenOrdersPrism.input_schema()

      assert Map.has_key?(schema.properties, :product_id)
      assert Map.has_key?(schema.properties, :status)
      assert schema.required == []
    end
  end

  describe "output_schema validation" do
    test "requires status and orders" do
      schema = CoinbaseOpenOrdersPrism.output_schema()

      assert "status" in schema.required
      assert "orders" in schema.required
    end
  end

  @tag :integration
  describe "handler/2" do
    test "returns error when API key not configured" do
      result = CoinbaseOpenOrdersPrism.run(%{})

      assert {:error, _reason} = result
    end
  end
end