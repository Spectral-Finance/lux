defmodule Lux.Lenses.TradingView.ChartDataLens do
  @moduledoc """
  Lens for fetching candlestick/ohlc chart data from TradingView's public API.

  ## Example

      alias Lux.Lenses.TradingView.ChartDataLens

      ChartDataLens.focus(%{
        symbol: "BINANCE:BTCUSDT",
        interval: "D",
        from: 1700000000,
        to: 1700604800
      })
  """

  use Lux.Lens,
    name: "TradingView Chart Data",
    description: "Fetches OHLCV candlestick data from TradingView for technical analysis",
    url: "https://api.tradingview.io/v3/quotes/candles",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        symbol: %{
          type: :string,
          description: "TradingView symbol (e.g., 'BINANCE:BTCUSDT', 'NASDAQ:AAPL')"
        },
        interval: %{
          type: :string,
          description: "Candle interval",
          enum: [
            "1", "3", "5", "15", "30",
            "45", "60", "120", "240",
            "1D", "1W", "1M"
          ]
        },
        from: %{
          type: :integer,
          description: "Start timestamp (Unix epoch seconds)"
        },
        to: %{
          type: :integer,
          description: "End timestamp (Unix epoch seconds)"
        }
      },
      required: ["symbol", "interval", "from", "to"]
    }

  @doc """
  Fetches candlestick data for the given symbol and time range.
  """
  def focus(params \ %{}, opts \ []) do
    __MODULE__.view()
    |> Map.update!(:params, &Map.merge(&1, params))
    |> Lux.Lens.authenticate()
    |> Map.update!(:params, &before_focus/1)
    |> Lux.Lens.focus(opts)
  end

  def before_focus(params) do
    params
    |> Map.take(["symbol", "interval", "from", "to"])
    |> Map.update(:range, fn _ -> ["last"] end, fn _ -> ["last"] end)
  end

  @impl true
  def after_focus(%{"data" => [_ | _] = candles}) when is_list(candles) do
    result =
      Enum.map(candles, fn c ->
        %{
          symbol: c["symbol"],
          open: float_or_nil(c["open"]),
          high: float_or_nil(c["high"]),
          low: float_or_nil(c["low"]),
          close: float_or_nil(c["close"]),
          volume: float_or_nil(c["volume"]),
          time: c["time"],
          status: c["status"]
        }
      end)

    {:ok, %{candles: result}}
  end

  @impl true
  def after_focus(%{"summary" => summary}) do
    {:ok, %{summary: summary}}
  end

  @impl true
  def after_focus(%{"error" => error}) do
    {:error, error}
  end

  @impl true
  def after_focus(response) do
    {:ok, response}
  end

  defp float_or_nil(nil), do: nil
  defp float_or_nil(val) when is_binary(val), do: String.to_float(val)
  defp float_or_nil(val) when is_number(val), do: val
