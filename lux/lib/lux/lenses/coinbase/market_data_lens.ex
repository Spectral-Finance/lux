defmodule Lux.Lenses.Coinbase.MarketDataLens do
  @moduledoc """
  Lens for loading market data, tickers, product specs, and historical candles from Coinbase Advanced Trade.
  """
  use Lux.Lens,
    name: "Coinbase Market Data Lens",
    description: "Fetches live tickers, historical OHLCV candles, and product information from Coinbase Advanced Trade",
    schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: ["get_products", "get_product", "get_candles", "get_best_bid_ask", "get_market_trades"],
          description: "Market data query action"
        },
        product_id: %{
          type: :string,
          description: "Product identifier (e.g. BTC-USD, ETH-USD)"
        },
        product_ids: %{
          type: :array,
          items: %{type: :string},
          description: "List of product identifiers for batch pricebook queries"
        },
        granularity: %{
          type: :string,
          enum: ["ONE_MINUTE", "FIVE_MINUTE", "FIFTEEN_MINUTE", "ONE_HOUR", "SIX_HOUR", "ONE_DAY"],
          description: "Candle bar time interval"
        },
        limit: %{
          type: :integer,
          description: "Maximum items to return"
        }
      },
      required: ["action"]
    }

  require Logger
  import Lux.Python

  @impl true
  def focus(params) do
    action = Map.get(params, "action") || Map.get(params, :action) || "get_products"
    product_id = Map.get(params, "product_id") || Map.get(params, :product_id)
    product_ids = Map.get(params, "product_ids") || Map.get(params, :product_ids)
    granularity = Map.get(params, "granularity") || Map.get(params, :granularity) || "ONE_HOUR"
    limit = Map.get(params, "limit") || Map.get(params, :limit) || 50

    python_result =
      python variables: %{
               action: action,
               product_id: product_id,
               product_ids: product_ids,
               granularity: granularity,
               limit: limit
             } do
        ~PY"""
        from lux.coinbase.rest import CoinbaseRestClient

        client = CoinbaseRestClient()
        res = {}

        if action == "get_products":
            prods = client.get_products(limit=limit)
            res = {"status": "ok", "products": [p.model_dump() for p in prods]}
        elif action == "get_product":
            prod = client.get_product(product_id)
            res = {"status": "ok", "product": prod.model_dump()}
        elif action == "get_candles":
            candles = client.get_candles(product_id=product_id, granularity=granularity)
            res = {"status": "ok", "candles": [c.model_dump() for c in candles]}
        elif action == "get_best_bid_ask":
            tickers = client.get_best_bid_ask(product_ids=product_ids)
            res = {"status": "ok", "tickers": [t.model_dump() for t in tickers]}
        elif action == "get_market_trades":
            trades = client.get_market_trades(product_id=product_id, limit=limit)
            res = {"status": "ok", "trades": trades}
        else:
            res = {"status": "error", "message": f"Unsupported action {action}"}

        res
        """
      end

    after_focus(python_result)
  end

  @doc """
  Transforms the Python client response into a standardized Elixir map.
  """
  def after_focus(%{"status" => "ok"} = result) do
    {:ok, result}
  end

  def after_focus(%{"status" => "error", "message" => msg}) do
    {:error, msg}
  end

  def after_focus(%{"error" => err}) do
    {:error, err}
  end

  def after_focus(other) when is_map(other) do
    {:ok, other}
  end

  def after_focus(err) do
    {:error, "Unexpected market data response: #{inspect(err)}"}
  end
end
