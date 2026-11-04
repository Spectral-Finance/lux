defmodule Lux.Prisms.Hyperliquid.HyperliquidCancelOrderPrismTest do
  use ExUnit.Case, async: false

  @moduletag :unit

  alias Lux.Prisms.HyperliquidCancelOrderPrism

  @valid_input %{
    "coin" => "ETH",
    "order_id" => 123_456
  }

  describe "SCENARIO_HAPPY_PATH (happy_path)" do
    test "validates input schema for a well-formed cancellation" do
      prism = HyperliquidCancelOrderPrism.view()

      assert prism.input_schema.required == ["coin", "order_id"]
      assert Map.has_key?(prism.input_schema.properties, :coin)
      assert Map.has_key?(prism.input_schema.properties, :order_id)
      assert Map.has_key?(prism.input_schema.properties, :vault_address)
    end

    test "validates output schema" do
      prism = HyperliquidCancelOrderPrism.view()

      assert prism.output_schema.required == ["status", "cancelled_order"]
      assert Map.has_key?(prism.output_schema.properties, :status)
      assert Map.has_key?(prism.output_schema.properties, :cancelled_order)
    end
  end

  describe "SCENARIO_BOUNDARY (null / empty / boundary)" do
    test "rejects empty input map" do
      assert {:error, "Order ID must be a positive integer"} ==
               HyperliquidCancelOrderPrism.run(%{}, nil)
    end

    test "rejects null order id" do
      input = Map.put(@valid_input, "order_id", nil)
      assert {:error, "Order ID must be a positive integer"} ==
               HyperliquidCancelOrderPrism.run(input, nil)
    end

    test "accepts order id at the lower boundary (1 proceeds to auth)" do
      input = Map.put(@valid_input, "order_id", 1)
      assert result = HyperliquidCancelOrderPrism.run(input, nil)
      refute result == {:error, "Order ID must be a positive integer"}
    end
  end

  describe "SCENARIO_NEGATIVE_FAILURE (negative)" do
    test "rejects zero order id" do
      input = Map.put(@valid_input, "order_id", 0)
      assert {:error, "Order ID must be a positive integer"} ==
               HyperliquidCancelOrderPrism.run(input, nil)
    end

    test "rejects negative order id" do
      input = Map.put(@valid_input, "order_id", -123_456)
      assert {:error, "Order ID must be a positive integer"} ==
               HyperliquidCancelOrderPrism.run(input, nil)
    end

    test "rejects non-integer order id" do
      input = Map.put(@valid_input, "order_id", "123456")
      assert {:error, "Order ID must be a positive integer"} ==
               HyperliquidCancelOrderPrism.run(input, nil)
    end
  end
end
