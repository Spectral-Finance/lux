defmodule Lux.Lenses.Coinbase.MarketDataLensTest do
  use UnitCase, async: true

  alias Lux.Lenses.Coinbase.MarketDataLens

  describe "view/0" do
    test "returns valid lens struct" do
      lens = MarketDataLens.view()

      assert lens.name == "Coinbase Market Data"
      assert lens.description =~ "Coinbase"
      assert lens.url =~ "api.coinbase.com"
    end

    test "schema defines all actions" do
      lens = MarketDataLens.view()
      actions = lens.schema.properties.action.enum

      expected = [
        "list_products",
        "get_product",
        "get_product_book",
        "best_bid_ask",
        "market_trades",
        "candles"
      ]

      for action <- expected do
        assert action in actions
      end
    end
  end

  describe "before_focus/1" do
    test "routes list_products action" do
      params = %{"action" => "list_products", "limit" => 10}
      result = MarketDataLens.before_focus(params)

      assert result["action"] == "list_products"
      assert result["endpoint"] == "/products"
    end

    test "routes get_product action" do
      params = %{"action" => "get_product", "product_id" => "BTC-USD"}
      result = MarketDataLens.before_focus(params)

      assert result["action"] == "get_product"
      assert result["endpoint"] == "/products/BTC-USD"
    end

    test "routes candles action" do
      params = %{
        "action" => "candles",
        "product_id" => "BTC-USD",
        "start" => "2024-01-01T00:00:00Z",
        "end" => "2024-01-02T00:00:00Z",
        "granularity" => 3600
      }

      result = MarketDataLens.before_focus(params)

      assert result["action"] == "candles"
      assert result["endpoint"] == "/products/BTC-USD/candles"
    end

    test "routes market_trades action" do
      params = %{"action" => "market_trades", "product_id" => "ETH-USD"}
      result = MarketDataLens.before_focus(params)

      assert result["action"] == "market_trades"
      assert result["endpoint"] == "/products/ETH-USD/ticker"
    end

    test "routes best_bid_ask action" do
      params = %{
        "action" => "best_bid_ask",
        "product_ids" => ["BTC-USD", "ETH-USD"]
      }

      result = MarketDataLens.before_focus(params)

      assert result["action"] == "best_bid_ask"
      assert result["endpoint"] == "/best_bid_ask"
    end

    test "routes get_product_book action" do
      params = %{
        "action" => "get_product_book",
        "product_id" => "BTC-USD",
        "limit" => 5
      }

      result = MarketDataLens.before_focus(params)

      assert result["action"] == "get_product_book"
      assert result["endpoint"] == "/product_book"
    end
  end

  describe "after_focus/1" do
    test "handles error response" do
      result = MarketDataLens.after_focus(%{"error" => "Not found"})
      assert result == {:error, "Not found"}
    end

    test "handles map response" do
      result = MarketDataLens.after_focus(%{"products" => []})
      assert result == {:ok, %{"products" => []}}
    end

    test "handles list response" do
      result = MarketDataLens.after_focus([%{"id" => "BTC-USD"}])
      assert result == {:ok, %{items: [%{"id" => "BTC-USD"}]}}
    end
  end
end
