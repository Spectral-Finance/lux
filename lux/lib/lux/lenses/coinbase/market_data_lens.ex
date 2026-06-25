defmodule Lux.Lenses.Coinbase.MarketDataLens do
  @moduledoc """
  A lens that fetches public market data from Coinbase Advanced Trade API.

  Supports GET endpoints:
  - Products listing
  - Single product info
  - Product book (order book)
  - Best bid/ask
  - Market trades
  - Candles (kline data)

  No authentication required for public market data.

  ## Example

      # List all products
      iex> Lux.Lenses.Coinbase.MarketDataLens.focus(%{action: :list_products})

      # Get candles for BTC-USD
      iex> Lux.Lenses.Coinbase.MarketDataLens.focus(%{
      ...>   action: :candles,
      ...>   product_id: "BTC-USD",
      ...>   start: "2024-01-01T00:00:00Z",
      ...>   end: "2024-01-02T00:00:00Z",
      ...>   granularity: 3600
      ...> })

      # Get best bid/ask
      iex> Lux.Lenses.Coinbase.MarketDataLens.focus(%{
      ...>   action: :best_bid_ask,
      ...>   product_ids: ["BTC-USD", "ETH-USD"]
      ...> })
  """

  use Lux.Lens,
    name: "Coinbase Market Data",
    description: "Fetches public market data from Coinbase Advanced Trade API (products, candles, order book, trades, bid/ask)",
    url: "https://api.coinbase.com/api/v3/brokerage",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "The market data action to perform",
          enum: [
            "list_products",
            "get_product",
            "get_product_book",
            "best_bid_ask",
            "market_trades",
            "candles"
          ]
        },
        product_id: %{
          type: :string,
          description: "Product identifier (e.g., 'BTC-USD')"
        },
        product_ids: %{
          type: :array,
          description: "List of product identifiers",
          items: %{type: :string}
        },
        start: %{
          type: :string,
          description: "Start timestamp for candles/trades (ISO 8601)"
        },
        end: %{
          type: :string,
          description: "End timestamp for candles/trades (ISO 8601)"
        },
        granularity: %{
          type: :integer,
          description: "Candle granularity in seconds (300, 900, 3600, 14400, 86400)"
        },
        limit: %{
          type: :integer,
          description: "Maximum number of results to return"
        },
        product_type: %{
          type: :string,
          description: "Filter by product type (SPOT, FUTURE)",
          enum: ["SPOT", "FUTURE"]
        },
        aggregation_price_increment: %{
          type: :string,
          description: "Price aggregation increment for order book"
        }
      },
      required: ["action"]
    }

  alias Lux.Integrations.Coinbase

  @doc """
  Routes the focus request to the appropriate Coinbase REST endpoint.
  """
  def after_focus(%{"error" => msg}) do
    {:error, msg}
  end

  def after_focus(body) when is_map(body) do
    {:ok, body}
  end

  def after_focus(body) when is_list(body) do
    {:ok, %{items: body}}
  end

  def after_focus(body), do: {:ok, body}

  @doc """
  Transforms params into the correct URL path and query parameters
  for the Coinbase Advanced Trade API.
  """
  def before_focus(params) do
    action = Map.get(params, "action", Map.get(params, :action))

    case action do
      "list_products" ->
        %{
          "action" => action,
          "endpoint" => "/products",
          "params" => Map.take(params, ["limit", "offset", "product_type", "product_ids",
                                         "contract_expiry_type", "expiring_contract_status",
                                         "get_tradability_status", "get_all_products"])
        }

      "get_product" ->
        product_id = params["product_id"] || params[:product_id]
        %{
          "action" => action,
          "endpoint" => "/products/#{product_id}",
          "params" => Map.take(params, ["get_tradability_status"])
        }

      "get_product_book" ->
        product_id = params["product_id"] || params[:product_id]
        %{
          "action" => action,
          "endpoint" => "/product_book",
          "params" => Map.take(params, ["product_id", "limit", "aggregation_price_increment"])
        }

      "best_bid_ask" ->
        %{
          "action" => action,
          "endpoint" => "/best_bid_ask",
          "params" => Map.take(params, ["product_ids"])
        }

      "market_trades" ->
        product_id = params["product_id"] || params[:product_id]
        %{
          "action" => action,
          "endpoint" => "/products/#{product_id}/ticker",
          "params" => Map.take(params, ["limit", "start", "end"])
        }

      "candles" ->
        product_id = params["product_id"] || params[:product_id]
        %{
          "action" => action,
          "endpoint" => "/products/#{product_id}/candles",
          "params" => Map.take(params, ["start", "end", "granularity", "limit"])
        }

      _ ->
        %{
          "action" => action,
          "endpoint" => "/",
          "params" => params
        }
    end
  end
end
