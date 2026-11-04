defmodule Lux.Prisms.Hyperliquid.HyperliquidExecuteOrderPrismTest do
  use ExUnit.Case, async: false

  @moduletag :unit

  alias Lux.Prisms.Hyperliquid.HyperliquidExecuteOrderPrism

  @valid_input %{
    "coin" => "ETH",
    "is_buy" => true,
    "sz" => 0.1,
    "limit_px" => 2800.0,
    "order_type" => %{"limit" => %{"tif" => "Gtc"}},
    "reduce_only" => false
  }

  describe "SCENARIO_HAPPY_PATH (happy_path)" do
    test "validates input schema for a well-formed order" do
      prism = HyperliquidExecuteOrderPrism.view()

      assert prism.input_schema.required ==
               ["coin", "is_buy", "sz", "limit_px", "order_type"]
      assert Map.has_key?(prism.input_schema.properties, :coin)
      assert Map.has_key?(prism.input_schema.properties, :is_buy)
      assert Map.has_key?(prism.input_schema.properties, :sz)
      assert Map.has_key?(prism.input_schema.properties, :limit_px)
      assert Map.has_key?(prism.input_schema.properties, :order_type)
      assert Map.has_key?(prism.input_schema.properties, :reduce_only)
      assert Map.has_key?(prism.input_schema.properties, :vault_address)
    end

    test "validates output schema" do
      prism = HyperliquidExecuteOrderPrism.view()

      assert prism.output_schema.required == ["status", "order_result"]
      assert Map.has_key?(prism.output_schema.properties, :status)
      assert Map.has_key?(prism.output_schema.properties, :order_result)
    end
  end

  describe "SCENARIO_BOUNDARY (null / empty / boundary)" do
    test "rejects empty input map" do
      assert {:error, "Order size must be a positive number"} ==
               HyperliquidExecuteOrderPrism.run(%{}, nil)
    end

    test "rejects null size input" do
      input = Map.put(@valid_input, "sz", nil)
      assert {:error, "Order size must be a positive number"} ==
               HyperliquidExecuteOrderPrism.run(input, nil)
    end

    test "accepts order size just above the lower boundary proceeds to auth" do
      input = Map.put(@valid_input, "sz", 0.000001)
      assert result = HyperliquidExecuteOrderPrism.run(input, nil)
      refute result == {:error, "Order size must be a positive number"}
    end

    test "accepts limit price just above the lower boundary proceeds to auth" do
      input = Map.put(@valid_input, "limit_px", 0.01)
      assert result = HyperliquidExecuteOrderPrism.run(input, nil)
      refute result == {:error, "Limit price must be a positive number"}
    end
  end

  describe "SCENARIO_NEGATIVE_FAILURE (negative)" do
    test "rejects zero order size" do
      input = Map.put(@valid_input, "sz", 0)
      assert {:error, "Order size must be a positive number"} ==
               HyperliquidExecuteOrderPrism.run(input, nil)
    end

    test "rejects negative order size" do
      input = Map.put(@valid_input, "sz", -0.1)
      assert {:error, "Order size must be a positive number"} ==
               HyperliquidExecuteOrderPrism.run(input, nil)
    end

    test "rejects zero limit price" do
      input = Map.put(@valid_input, "limit_px", 0)
      assert {:error, "Limit price must be a positive number"} ==
               HyperliquidExecuteOrderPrism.run(input, nil)
    end

    test "rejects negative limit price" do
      input = Map.put(@valid_input, "limit_px", -2800.0)
      assert {:error, "Limit price must be a positive number"} ==
               HyperliquidExecuteOrderPrism.run(input, nil)
    end

    test "rejects non-numeric size" do
      input = Map.put(@valid_input, "sz", "0.1")
      assert {:error, "Order size must be a positive number"} ==
               HyperliquidExecuteOrderPrism.run(input, nil)
    end

    test "handles missing configuration gracefully without crashing" do
      input = Map.put(@valid_input, "sz", 0.1)
      accounts = Application.get_env(:lux, :accounts)
      Application.delete_env(:lux, :accounts)
      try do
        assert {:error, "Hyperliquid account private key is not configured"} ==
                 HyperliquidExecuteOrderPrism.run(input, nil)
      after
        Application.put_env(:lux, :accounts, accounts)
      end
    end
  end

  describe "SCENARIO_DEFECT_REGRESSION (regression)" do
    @tag :regression
    test "rejects non-positive order size before any execution path is reached" do
      input = Map.put(@valid_input, "sz", 0)

      assert {:error, "Order size must be a positive number"} ==
               HyperliquidExecuteOrderPrism.run(input, nil)
    end
  end
end
