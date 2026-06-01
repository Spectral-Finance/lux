defmodule Lux.Lenses.Binance.Market.GetKlines do
  @moduledoc """
  A lens for fetching candlestick (kline) data for a symbol from Binance.

  Each kline is returned as a map with OHLCV fields.

  ## Examples

      iex> GetKlines.focus(%{symbol: "BTCUSDT", interval: "1h", limit: 3})
      {:ok, [
        %{
          open_time: 1625000000000,
          open: "50000.00",
          high: "51000.00",
          low: "49000.00",
          close: "50500.00",
          volume: "1234.56",
          close_time: 1625003599999
        },
        ...
      ]}
  """

  use Lux.Lens,
    name: "Binance Get Klines",
    description: "Fetches candlestick (OHLCV) data for a symbol from Binance",
    url: "https://api.binance.com/api/v3/klines",
    method: :get,
    headers: [{"Content-Type", "application/json"}],
    schema: %{
      type: :object,
      properties: %{
        symbol: %{
          type: :string,
          description: "Trading pair symbol, e.g. BTCUSDT"
        },
        interval: %{
          type: :string,
          description: "Kline interval: 1s, 1m, 3m, 5m, 15m, 30m, 1h, 2h, 4h, 6h, 8h, 12h, 1d, 3d, 1w, 1M",
          default: "1h"
        },
        limit: %{
          type: :integer,
          description: "Number of klines to return (max 1000)",
          default: 100
        },
        startTime: %{
          type: :integer,
          description: "Start time in milliseconds"
        },
        endTime: %{
          type: :integer,
          description: "End time in milliseconds"
        }
      },
      required: ["symbol", "interval"]
    }

  @impl true
  def after_focus(klines) when is_list(klines) do
    {:ok, Enum.map(klines, &parse_kline/1)}
  end

  def after_focus(%{"code" => code, "msg" => msg}) do
    {:error, %{code: code, message: msg}}
  end

  defp parse_kline([
    open_time, open, high, low, close, volume,
    close_time, quote_volume, trades,
    taker_buy_base, taker_buy_quote, _ignore
  ]) do
    %{
      open_time: open_time,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: volume,
      close_time: close_time,
      quote_volume: quote_volume,
      trades: trades,
      taker_buy_base_volume: taker_buy_base,
      taker_buy_quote_volume: taker_buy_quote
    }
  end
end
