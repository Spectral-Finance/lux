defmodule Lux.Prisms.TradingView.AnalyzeSeriesTest do
  use UnitCase, async: true

  alias Lux.Prisms.TradingView.AnalyzeSeries

  @candles [
    %{time: 1, open: 1, high: 2, low: 1, close: 1, volume: 100},
    %{time: 2, open: 2, high: 3, low: 2, close: 2, volume: 100},
    %{time: 3, open: 3, high: 4, low: 3, close: 3, volume: 100}
  ]

  test "returns technical analysis through the prism" do
    assert {:ok, %{analysis: analysis}} =
             AnalyzeSeries.handler(
               %{candles: @candles, sma_period: 2, ema_period: 2, rsi_period: 2},
               nil
             )

    assert length(analysis.indicators.sma) == 3
  end
end
