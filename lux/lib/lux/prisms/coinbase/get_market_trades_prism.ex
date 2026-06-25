defmodule Lux.Prisms.Coinbase.GetMarketTradesPrism do
  @moduledoc """
  A prism that fetches the last trades for a given product.

  ## Example

      iex> Lux.Prisms.Coinbase.GetMarketTradesPrism.run(%{
      ...>   product_id: "BTC-USD",
      ...>   limit: 10
      ...> })
      {:ok, %{trades: [...], product_id: "BTC-USD"}}

  Uses the `coinbase-advanced-py` Python SDK.
  """

  use Lux.Prism,
    name: "Coinbase Market Trades",
    description: "Fetches last trades (ticks), best bid/ask, and 24h volume for a product",
    input_schema: %{
      type: :object,
      properties: %{
        product_id: %{
          type: :string,
          description: "Product identifier (e.g., 'BTC-USD')"
        },
        limit: %{
          type: :integer,
          description: "Maximum number of trades to return"
        },
        start: %{
          type: :string,
          description: "Start timestamp (ISO 8601)"
        },
        end: %{
          type: :string,
          description: "End timestamp (ISO 8601)"
        }
      },
      required: ["product_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        trades: %{type: :array, description: "List of trade records"},
        product_id: %{type: :string},
        best_bid: %{type: :number, description: "Best bid price"},
        best_ask: %{type: :number, description: "Best ask price"},
        base_volume: %{type: :string, description: "24h base volume"},
        quote_volume: %{type: :string, description: "24h quote volume"}
      }
    }

  import Lux.Python
  require Lux.Python

  def handler(input, _ctx) do
    python variables: %{input: input} do
      ~PY"""
      import os
      from coinbase.rest.market_data import get_market_trades

      api_key = os.getenv("COINBASE_API_KEY", "")
      api_secret = os.getenv("COINBASE_API_SECRET", "")

      from coinbase.rest.rest_base import RESTBase
      client = RESTBase(api_key=api_key, api_secret=api_secret if api_key else None)
      get_market_trades.__self__ = client

      product_id = input.get("product_id")
      if not product_id:
          raise ValueError("product_id is required")

      params = {"limit": input.get("limit"), "start": input.get("start"), "end": input.get("end")}
      params = {k: v for k, v in params.items() if v is not None}

      response = get_market_trades(product_id, **params)

      trades = response.data.get("trades", []) if hasattr(response, 'data') else []
      best_bid = response.data.get("best_bid") if hasattr(response, 'data') else None
      best_ask = response.data.get("best_ask") if hasattr(response, 'data') else None
      base_volume = response.data.get("base_volume") if hasattr(response, 'data') else None
      quote_volume = response.data.get("quote_volume") if hasattr(response, 'data') else None

      {
          "trades": trades,
          "product_id": product_id,
          "best_bid": best_bid,
          "best_ask": best_ask,
          "base_volume": base_volume,
          "quote_volume": quote_volume
      }
      """
    end
    |> handle_python_result()
  end

  defp handle_python_result(result) when is_map(result) do
    case Map.get(result, "error") do
      nil -> {:ok, result}
      err when is_binary(err) -> {:error, err}
      _ -> {:ok, result}
    end
  end

  defp handle_python_result({:error, error}) do
    {:error, error}
  end
end
