defmodule Lux.Prisms.TradingView.IndicatorCalculatorPrism do
  @moduledoc """
  Calculates core technical indicators (RSI, MACD, Bollinger Bands, EMAs) for a price series.
  """

  use Lux.Prism,
    name: "TradingView Indicator Calculator",
    description: "Computes RSI, MACD, Bollinger Bands, and moving averages on price series",
    input_schema: %{
      type: :object,
      properties: %{
        prices: %{type: :array, description: "Historical close price series"},
        rsi_period: %{type: :integer, default: 14},
        bollinger_period: %{type: :integer, default: 20}
      },
      required: ["prices"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        current_price: %{type: :number},
        rsi: %{type: :number},
        macd: %{type: :object},
        bollinger_bands: %{type: :object},
        ema_20: %{type: :number}
      },
      required: ["current_price"]
    }

  alias Lux.TradingView.Indicators

  def handler(input, _ctx) do
    prices = Map.get(input, :prices) || Map.get(input, "prices", [])
    rsi_p = Map.get(input, :rsi_period) || Map.get(input, "rsi_period", 14)
    bb_p = Map.get(input, :bollinger_period) || Map.get(input, "bollinger_period", 20)

    current_price = List.last(prices) || 0.0

    rsi = Indicators.calculate_rsi(prices, rsi_p)
    macd = Indicators.calculate_macd(prices)
    bb = Indicators.calculate_bollinger_bands(prices, bb_p)
    ema20 = Indicators.calculate_ema(prices, 20)

    {:ok,
     %{
       current_price: current_price * 1.0,
       rsi: rsi,
       macd: macd,
       bollinger_bands: bb,
       ema_20: ema20
     }}
  end
end
