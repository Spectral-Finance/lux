defmodule Lux.Prisms.Coinbase.GetMarketTradesPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.Coinbase.GetMarketTradesPrism

  describe "view/0" do
    test "returns valid prism struct with schema" do
      prism = GetMarketTradesPrism.view()

      assert prism.name == "Coinbase Market Trades"
      assert prism.input_schema.required == ["product_id"]
    end

    test "input schema has product_id and optional fields" do
      prism = GetMarketTradesPrism.view()
      props = prism.input_schema.properties

      assert Map.has_key?(props, :product_id)
      assert Map.has_key?(props, :limit)
      assert Map.has_key?(props, :start)
      assert Map.has_key?(props, :end)
    end

    test "output schema defines trades, bid/ask, and volume" do
      prism = GetMarketTradesPrism.view()
      props = prism.output_schema.properties

      assert Map.has_key?(props, :trades)
      assert Map.has_key?(props, :best_bid)
      assert Map.has_key?(props, :best_ask)
      assert Map.has_key?(props, :base_volume)
      assert Map.has_key?(props, :quote_volume)
    end
  end

  describe "handler/2" do
    test "requires product_id" do
      result = GetMarketTradesPrism.handler(%{}, nil)
      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end

    test "handler with valid product_id" do
      result =
        GetMarketTradesPrism.handler(%{
          product_id: "BTC-USD",
          limit: 5
        }, nil)

      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end
  end
end
