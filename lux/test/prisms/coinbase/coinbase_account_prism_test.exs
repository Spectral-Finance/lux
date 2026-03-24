defmodule Lux.Prisms.Coinbase.CoinbaseAccountPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Coinbase.CoinbaseAccountPrism

  describe "input_schema validation" do
    test "has optional account_id and get_holds" do
      schema = CoinbaseAccountPrism.input_schema()

      assert Map.has_key?(schema.properties, :account_id)
      assert Map.has_key?(schema.properties, :get_holds)
      assert schema.required == []
    end
  end

  describe "output_schema validation" do
    test "requires status" do
      schema = CoinbaseAccountPrism.output_schema()

      assert "status" in schema.required
    end
  end

  @tag :integration
  describe "handler/2" do
    test "returns error when API key not configured" do
      result = CoinbaseAccountPrism.run(%{})

      assert {:error, _reason} = result
    end
  end
end