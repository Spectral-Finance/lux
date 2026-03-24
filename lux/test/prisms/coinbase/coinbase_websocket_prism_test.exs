defmodule Lux.Prisms.Coinbase.CoinbaseWebSocketPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Coinbase.CoinbaseWebSocketPrism

  describe "input_schema validation" do
    test "validates required action field" do
      schema = CoinbaseWebSocketPrism.input_schema()

      assert "action" in schema.required
    end

    test "validates action enum" do
      schema = CoinbaseWebSocketPrism.input_schema()
      action_property = schema.properties.action

      assert "subscribe" in action_property.enum
      assert "unsubscribe" in action_property.enum
      assert "get_status" in action_property.enum
    end
  end

  describe "output_schema validation" do
    test "requires status" do
      schema = CoinbaseWebSocketPrism.output_schema()

      assert "status" in schema.required
    end
  end

  describe "handler/2 get_status" do
    test "returns status without credentials" do
      {:ok, result} = CoinbaseWebSocketPrism.run(%{action: "get_status"})

      assert result.status == "success"
      assert Map.has_key?(result, :available_channels)
    end
  end
end