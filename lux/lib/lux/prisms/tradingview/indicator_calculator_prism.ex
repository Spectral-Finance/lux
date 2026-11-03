defmodule Lux.Prisms.TradingView.IndicatorCalculatorPrism do
  @moduledoc """
  Calculates core technical indicators (RSI, MACD, Bollinger Bands, EMAs, ATR, Stochastic)
  for a price series or OHLCV candlestick array.
  """

  use Lux.Prism,
    name: "TradingView Indicator Calculator",
    description: "Computes RSI, MACD, Bollinger Bands, and moving averages on price series",
    input_schema: %{
      type: :object,
      properties: %{
        prices: %{type: :array, description: "Historical close prices series"},
        candles: %{type: :array, description: "Historical OHLCV candle maps"},
        rsi_period: %{type: :integer, default: 14},
        bollinger_period: %{type: :integer, default: 20}
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        current_price: %{type: :number},
        rsi: %{type: :number},
        macd: %{type: :object},
        bollinger_bands: %{type: :object},
        ema_20: %{type: :number},
        atr: %{type: :number},
        stochastic: %{type: :object}
      },
      required: ["current_price", "rsi", "macd", "bollinger_bands"]
    }

  alias Lux.TradingView.Indicators

  def handler(input, _ctx) do
    candles = Map.get(input, :candles) || Map.get(input, "candles")

    prices =
      cond do
        Map.has_key?(input, :prices) -> Map.get(input, :prices)
        Map.has_key?(input, "prices") -> Map.get(input, "prices")
        is_list(candles) -> Enum.map(candles, fn c -> c[:close] || c["close"] || 0.0 end)
        true -> []
      end

    rsi_p = Map.get(input, :rsi_period) || Map.get(input, "rsi_period", 14)
    bb_p = Map.get(input, :bollinger_period) || Map.get(input, "bollinger_period", 20)

    current_price = (List.last(prices) || 0.0) * 1.0

    rsi = Indicators.calculate_rsi(prices, rsi_p)
    macd = Indicators.calculate_macd(prices)
    bb = Indicators.calculate_bollinger_bands(prices, bb_p)
    ema20 = Indicators.calculate_ema(prices, 20) || current_price

    atr =
      if is_list(candles) and length(candles) > 14,
        do: Indicators.calculate_atr(candles, 14),
        else: 0.0

    stoch =
      if is_list(candles) and length(candles) >= 17,
        do: Indicators.calculate_stochastic(candles),
        else: %{k: 50.0, d: 50.0}

    {:ok,
     %{
       current_price: current_price,
       rsi: rsi,
       macd: macd,
       bollinger_bands: bb,
       ema_20: ema20,
       atr: atr,
       stochastic: stoch
     }}
  end
end
