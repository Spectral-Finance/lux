defmodule Lux.Prisms.Binance.GetKlinesPrism do
  @moduledoc """
  A prism for retrieving candlestick (OHLCV) data from Binance.

  Supports all standard timeframe intervals for both spot and futures markets.

  ## Examples

      iex> Lux.Prisms.Binance.GetKlinesPrism.handler(%{
      ...>   symbol: "BTCUSDT",
      ...>   interval: "1h",
      ...>   limit: 5
      ...> }, %{name: "Agent"})
      {:ok, %{
        symbol: "BTCUSDT",
        interval: "1h",
        klines: [%{
          open_time: 1625000000000,
          open: "35000.00",
          high: "35500.00",
          low: "34800.00",
          close: "35200.00",
          volume: "1234.567",
          close_time: 1625003599999
        }]
      }}
  """

  use Lux.Prism,
    name: "Binance Get Klines",
    description: "Retrieves candlestick/OHLCV data for a symbol on Binance",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{
          type: :string,
          description: "Trading pair symbol (e.g., 'BTCUSDT')"
        },
        interval: %{
          type: :string,
          description: "Candlestick interval",
          enum: ["1m", "3m", "5m", "15m", "30m", "1h", "2h", "4h", "6h", "8h", "12h", "1d", "3d", "1w", "1M"]
        },
        limit: %{
          type: :integer,
          description: "Number of candlesticks to return (max 1000)",
          default: 100
        },
        start_time: %{
          type: :integer,
          description: "Start time in milliseconds timestamp"
        },
        end_time: %{
          type: :integer,
          description: "End time in milliseconds timestamp"
        },
        futures: %{
          type: :boolean,
          description: "If true, query Futures market",
          default: false
        }
      },
      required: ["symbol", "interval"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string},
        interval: %{type: :string},
        klines: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              open_time: %{type: :integer},
              open: %{type: :string},
              high: %{type: :string},
              low: %{type: :string},
              close: %{type: :string},
              volume: %{type: :string},
              close_time: %{type: :integer}
            }
          }
        }
      },
      required: ["symbol", "interval", "klines"]
    }

  alias Lux.Integrations.Binance
  require Logger

  def handler(params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    futures = Map.get(params, :futures, false)

    Logger.info("Agent #{agent_name} fetching #{params.interval} klines for #{params.symbol}")

    path = if futures, do: "/fapi/v1/klines", else: "/api/v3/klines"

    query_params = %{symbol: params.symbol, interval: params.interval}
    |> maybe_add(:limit, Map.get(params, :limit, 100))
    |> maybe_add(:startTime, Map.get(params, :start_time))
    |> maybe_add(:endTime, Map.get(params, :end_time))

    case Binance.get(path, query_params, futures: futures) do
      {:ok, raw_klines} when is_list(raw_klines) ->
        klines = Enum.map(raw_klines, &parse_kline/1)
        Logger.info("Fetched #{length(klines)} klines for #{params.symbol}")
        {:ok, %{symbol: params.symbol, interval: params.interval, klines: klines}}

      {:error, {status, %{"msg" => msg}}} ->
        Logger.error("Binance klines error: #{status} - #{msg}")
        {:error, {status, msg}}

      {:error, reason} ->
        Logger.error("Binance klines request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp parse_kline([open_time, open, high, low, close, volume, close_time | _]) do
    %{
      open_time: open_time,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: volume,
      close_time: close_time
    }
  end

  defp maybe_add(map, _key, nil), do: map
  defp maybe_add(map, key, value), do: Map.put(map, key, value)
end
