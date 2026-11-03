defmodule Lux.Prisms.Coinbase.ProductCandlesPrism do
  @moduledoc """
  Processes and parses historical candlestick data from Coinbase Advanced Trade.
  """

  use Lux.Prism,
    name: "Coinbase Product Candles Prism",
    description: "Parses and maps historical candles with intervals and volume metrics",
    input_schema: %{
      type: :object,
      properties: %{
        candles: %{type: :array, description: "Raw candle data"},
        interval: %{type: :string, default: "1h"}
      },
      required: ["candles"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        granularity: %{type: :string},
        candles: %{type: :array},
        count: %{type: :integer}
      },
      required: ["granularity", "candles", "count"]
    }

  alias Lux.Integrations.Coinbase.MarketData

  def handler(input, _ctx) do
    raw_candles = Map.get(input, :candles) || Map.get(input, "candles", [])
    interval = Map.get(input, :interval) || Map.get(input, "interval", "1h")

    granularity = MarketData.map_granularity(interval)
    parsed = MarketData.parse_candles(raw_candles)

    {:ok,
     %{
       granularity: granularity,
       candles: parsed,
       count: length(parsed)
     }}
  end
end
