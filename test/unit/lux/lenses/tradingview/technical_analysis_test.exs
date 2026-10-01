defmodule Lux.Lenses.TradingView.TechnicalAnalysisTest do
  use ExUnit.Case, async: true
  alias Lux.Lenses.TradingView.TechnicalAnalysis

  test "calculates SMA correctly" do
    prices = [10, 20, 30, 40, 50]
    assert TechnicalAnalysis.sma(prices, 3) == [20.0, 30.0, 40.0]
  end

  test "calculates EMA correctly" do
    prices = [10, 20, 30, 40, 50]
    ema = TechnicalAnalysis.ema(prices, 3)
    assert length(ema) == 3
  end

  test "calculates RSI correctly" do
    prices = [44.34, 44.09, 44.15, 43.61, 44.33, 44.83, 45.10, 45.42, 45.84, 46.08, 45.89, 46.03, 45.61, 46.28, 46.28]
    rsi = TechnicalAnalysis.rsi(prices, 14)
    assert length(rsi) == 1
    assert hd(rsi) > 0 and hd(rsi) < 100
  end
end
