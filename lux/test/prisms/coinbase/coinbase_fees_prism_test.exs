defmodule Lux.Prisms.Coinbase.CoinbaseFeesPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Coinbase.CoinbaseFeesPrism

  describe "input_schema validation" do
    test "accepts empty input" do
      schema = CoinbaseFeesPrism.input_schema()

      assert schema.type == :object
      assert schema.required == []
    end
  end

  describe "output_schema validation" do
    test "requires status" do
      schema = CoinbaseFeesPrism.output_schema()

      assert "status" in schema.required
      assert Map.has_key?(schema.properties, :fees)
    end
  end

  @tag :integration
  describe "handler/2" do
    test "returns error when API key not configured" do
      result = CoinbaseFeesPrism.run(%{})

      assert {:error, _reason} = result
    end
  end
end