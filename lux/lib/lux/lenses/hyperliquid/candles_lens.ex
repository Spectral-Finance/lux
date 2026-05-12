defmodule Lux.Lenses.Hyperliquid.Candles do
  @moduledoc """
  Lens for fetching OHLCV candle data from the Hyperliquid API.

  Provides historical price data for a given coin with configurable
  interval and time range.

  ## Examples

      iex> Lux.Lenses.Hyperliquid.Candles.focus(%{
      ...>   coin: "BTC",
      ...>   interval: "1h",
      ...>   startTime: 1700000000,
      ...>   endTime: 1700086400
      ...> })
      {:ok, %{...}}
  """

  use Lux.Lens,
    name: "Hyperliquid Candles",
    description: "Fetches OHLCV candle data from Hyperliquid",
    url: "https://api.hyperliquid.xyz/info",
    method: :post,
    headers: [{"content-type", "application/json"}],
    schema: %{
      type: :object,
      properties: %{
        coin: %{
          type: :string,
          description: "The asset symbol (e.g. BTC, ETH)"
        },
        interval: %{
          type: :string,
          description: "Candle interval (e.g. 1m, 5m, 15m, 1h, 4h, 1d)",
          default: "1h"
        },
        startTime: %{
          type: :integer,
          description: "Start time as Unix timestamp in seconds"
        },
        endTime: %{
          type: :integer,
          description: "End time as Unix timestamp in seconds"
        }
      },
      required: ["coin", "startTime", "endTime"]
    }

  def before_focus(params) do
    %{
      type: "candle/snapshot",
      req: %{
        coin: Map.get(params, :coin),
        interval: Map.get(params, :interval, "1h"),
        startTime: Map.get(params, :startTime),
        endTime: Map.get(params, :endTime)
      }
    }
  end

  @impl true
  def after_focus(response) do
    {:ok, response}
  end
end
