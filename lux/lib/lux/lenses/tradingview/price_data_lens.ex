defmodule Lux.Lenses.TradingView.PriceDataLens do
  @moduledoc """
  Lens for fetching cryptocurrency price data from the Binance public API.

  Provides access to kline (candlestick) data, current prices, and 24-hour
  ticker statistics. No API key required for public market data endpoints.

  ## Examples

      # Fetch 100 hourly candles for BTC/USDT
      Lux.Lenses.TradingView.PriceDataLens.focus(%{
        symbol: "BTCUSDT",
        interval: "1h",
        limit: 100
      })

      # Fetch daily candles for ETH/USDT
      Lux.Lenses.TradingView.PriceDataLens.focus(%{
        symbol: "ETHUSDT",
        interval: "1d",
        limit: 30
      })

      # Get current price
      Lux.Lenses.TradingView.PriceDataLens.focus(%{
        symbol: "BTCUSDT",
        endpoint: "ticker"
      })
  """

  use Lux.Lens,
    name: "TradingView.PriceData",
    description: "Fetches cryptocurrency price data from Binance public API",
    url: "https://api.binance.com/api/v3/klines",
    method: :get,
    headers: [{"content-type", "application/json"}],
    schema: %{
      type: :object,
      properties: %{
        symbol: %{
          type: :string,
          description: "Trading pair symbol (e.g., BTCUSDT, ETHUSDT)",
          default: "BTCUSDT"
        },
        interval: %{
          type: :string,
          description: "Kline interval",
          enum: ["1m", "5m", "15m", "30m", "1h", "2h", "4h", "6h", "8h", "12h", "1d", "3d", "1w", "1M"],
          default: "1h"
        },
        limit: %{
          type: :integer,
          description: "Number of candles to fetch (max 1000)",
          default: 100,
          minimum: 1,
          maximum: 1000
        },
        endpoint: %{
          type: :string,
          description: "API endpoint type",
          enum: ["klines", "ticker", "ticker24h"],
          default: "klines"
        }
      },
      required: ["symbol"]
    }

  @doc """
  Prepares parameters and selects the appropriate API endpoint.
  """
  def before_focus(params) do
    endpoint = Map.get(params, :endpoint, "klines")

    case endpoint do
      "klines" ->
        params
        |> Map.put(:url, "https://api.binance.com/api/v3/klines")
        |> Map.put(:params, %{
          symbol: Map.get(params, :symbol, "BTCUSDT"),
          interval: Map.get(params, :interval, "1h"),
          limit: min(Map.get(params, :limit, 100), 1000)
        })

      "ticker" ->
        params
        |> Map.put(:url, "https://api.binance.com/api/v3/ticker/price")
        |> Map.put(:params, %{
          symbol: Map.get(params, :symbol, "BTCUSDT")
        })

      "ticker24h" ->
        params
        |> Map.put(:url, "https://api.binance.com/api/v3/ticker/24hr")
        |> Map.put(:params, %{
          symbol: Map.get(params, :symbol, "BTCUSDT")
        })
    end
  end

  @doc """
  Transforms the API response into a structured format.
  """
  @impl true
  def after_focus(response) when is_list(response) do
    # Kline data response
    parsed =
      Enum.map(response, fn kline ->
        case kline do
          [open_time, open, high, low, close, volume | _rest] ->
            %{
              open_time: open_time,
              open: parse_float(open),
              high: parse_float(high),
              low: parse_float(low),
              close: parse_float(close),
              volume: parse_float(volume)
            }

          _ ->
            nil
        end
      end)
      |> Enum.filter(& &1)

    {:ok, %{result: parsed, type: :klines}}
  end

  def after_focus(%{"symbol" => symbol, "price" => price}) do
    # Single ticker response
    {:ok, %{
      result: %{
        symbol: symbol,
        price: parse_float(price)
      },
      type: :ticker
    }}
  end

  def after_focus(%{"symbol" => symbol} = response) when is_map(response) do
    # 24h ticker response
    {:ok, %{
      result: %{
        symbol: symbol,
        last_price: parse_float(Map.get(response, "lastPrice", "0")),
        high_price: parse_float(Map.get(response, "highPrice", "0")),
        low_price: parse_float(Map.get(response, "lowPrice", "0")),
        volume: parse_float(Map.get(response, "volume", "0")),
        quote_volume: parse_float(Map.get(response, "quoteVolume", "0")),
        price_change: parse_float(Map.get(response, "priceChange", "0")),
        price_change_percent: parse_float(Map.get(response, "priceChangePercent", "0"))
      },
      type: :ticker_24h
    }}
  end

  def after_focus(%{"code" => code, "msg" => msg}) do
    {:error, %{code: code, message: msg}}
  end

  def after_focus(response) do
    {:error, "Unexpected response format: #{inspect(response)}"}
  end

  defp parse_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float, _} -> float
      :error -> value
    end
  end

  defp parse_float(value) when is_number(value), do: value
  defp parse_float(value), do: value
end
