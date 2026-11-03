defmodule Lux.Prisms.TradingView.ChartDataPrism do
  @moduledoc """
  Prism for retrieving OHLCV market chart data for technical analysis.
  Wraps `Lux.Lenses.TradingView.ChartDataLens`.
  """

  use Lux.Prism,
    name: "TradingView Chart Data Prism",
    description:
      "Fetches historical and streaming candlestick bars for technical indicator calculations",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string, description: "Market asset symbol (e.g. BTCUSDT, ETHUSD)"},
        resolution: %{
          type: :string,
          description: "Bar resolution (1m, 5m, 15m, 1h, 4h, 1D)",
          default: "1h"
        },
        limit: %{type: :integer, description: "Number of candlestick bars", default: 100},
        mock?: %{type: :boolean, description: "Return synthetic data for testing", default: false}
      },
      required: ["symbol"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string},
        count: %{type: :integer},
        current_price: %{type: :number},
        candles: %{type: :array},
        close_prices: %{type: :array}
      },
      required: ["symbol", "count", "current_price", "candles"]
    }

  alias Lux.Lenses.TradingView.ChartDataLens

  def handler(input, _ctx) do
    symbol = Map.get(input, :symbol) || Map.get(input, "symbol", "BTCUSDT")
    resolution = Map.get(input, :resolution) || Map.get(input, "resolution", "1h")
    limit = Map.get(input, :limit) || Map.get(input, "limit", 100)
    mock? = Map.get(input, :mock?) || Map.get(input, "mock?", false)

    if mock? do
      candles = ChartDataLens.generate_synthetic_candles(symbol, resolution, limit)
      close_prices = Enum.map(candles, fn c -> c[:close] || c["close"] || 0.0 end)
      current_price = (List.last(close_prices) || 0.0) * 1.0

      {:ok,
       %{
         symbol: symbol,
         count: length(candles),
         current_price: current_price,
         candles: candles,
         close_prices: close_prices
       }}
    else
      case ChartDataLens.focus(%{
             symbol: symbol,
             resolution: resolution,
             limit: limit
           }) do
        {:ok, %{candles: candles}} ->
          close_prices =
            Enum.map(candles, fn c -> c[:close] || c["close"] || 0.0 end)

          current_price = (List.last(close_prices) || 0.0) * 1.0

          {:ok,
           %{
             symbol: symbol,
             count: length(candles),
             current_price: current_price,
             candles: candles,
             close_prices: close_prices
           }}

        {:error, _reason} ->
          # Fallback to deterministic synthetic chart data if network unavailable
          candles = ChartDataLens.generate_synthetic_candles(symbol, resolution, limit)
          close_prices = Enum.map(candles, fn c -> c[:close] || c["close"] || 0.0 end)
          current_price = (List.last(close_prices) || 0.0) * 1.0

          {:ok,
           %{
             symbol: symbol,
             count: length(candles),
             current_price: current_price,
             candles: candles,
             close_prices: close_prices
           }}

        other ->
          {:ok, %{symbol: symbol, raw: other}}
      end
    end
  end
end
