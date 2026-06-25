defmodule Lux.Prisms.Coinbase.GetCandlesPrism do
  @moduledoc """
  A prism that fetches candlestick (kline) data for a product.

  ## Example

      iex> Lux.Prisms.Coinbase.GetCandlesPrism.run(%{
      ...>   product_id: "BTC-USD",
      ...>   start: "2024-01-01T00:00:00Z",
      ...>   end: "2024-01-02T00:00:00Z",
      ...>   granularity: 3600
      ...> })
      {:ok, %{candles: [...]}}

  Granularity options (seconds): 60, 300, 900, 3600, 14400, 86400
  """

  use Lux.Prism,
    name: "Coinbase Candles",
    description: "Fetches candlestick/kline data for historical price analysis",
    input_schema: %{
      type: :object,
      properties: %{
        product_id: %{
          type: :string,
          description: "Product identifier (e.g., 'BTC-USD')"
        },
        start: %{
          type: :string,
          description: "Start timestamp (ISO 8601)"
        },
        end: %{
          type: :string,
          description: "End timestamp (ISO 8601)"
        },
        granularity: %{
          type: :integer,
          description: "Candle granularity in seconds (60, 300, 900, 3600, 14400, 86400)",
          enum: [60, 300, 900, 3600, 14400, 86400]
        },
        limit: %{
          type: :integer,
          description: "Maximum number of candles to return"
        }
      },
      required: ["product_id", "start", "end", "granularity"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        candles: %{
          type: :array,
          description: "List of candle objects with [start, low, high, open, close, volume]",
          items: %{type: :array}
        }
      }
    }

  import Lux.Python
  require Lux.Python

  def handler(input, _ctx) do
    python variables: %{input: input} do
      ~PY"""
      import os
      from coinbase.rest.market_data import get_candles

      api_key = os.getenv("COINBASE_API_KEY", "")
      api_secret = os.getenv("COINBASE_API_SECRET", "")

      from coinbase.rest.rest_base import RESTBase
      client = RESTBase(api_key=api_key, api_secret=api_secret if api_key else None)
      get_candles.__self__ = client

      product_id = input.get("product_id")
      start = input.get("start")
      end_time = input.get("end")
      granularity = input.get("granularity")

      if not all([product_id, start, end_time, granularity]):
          missing = []
          if not product_id: missing.append("product_id")
          if not start: missing.append("start")
          if not end_time: missing.append("end")
          if not granularity: missing.append("granularity")
          raise ValueError(f"Missing required fields: {', '.join(missing)}")

      params = {"limit": input.get("limit")}
      params = {k: v for k, v in params.items() if v is not None}

      response = get_candles(product_id, start, end_time, granularity, **params)
      {"candles": response.data if hasattr(response, 'data') else []}
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
