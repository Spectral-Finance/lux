defmodule Lux.TradingView.IndicatorsTest do
  use UnitCase, async: true

  alias Lux.TradingView.Indicators

  @sample_prices [
    44.34, 44.09, 44.15, 43.61, 44.33, 44.83, 45.10, 45.42, 45.84, 46.08,
    45.89, 46.03, 45.61, 46.28, 46.28, 46.00, 46.03, 46.41, 46.22, 45.64,
    46.21, 46.25, 45.71, 46.45, 45.78, 45.35, 44.03, 44.18, 44.22, 44.57,
    43.42, 42.66, 43.13
  ]

  describe "calculate_sma/2" do
    test "computes simple moving average" do
      prices = [10.0, 20.0, 30.0, 40.0, 50.0]
      sma = Indicators.calculate_sma(prices, 3)
      # Last 3: 30, 40, 50 -> avg = 40.0
      assert sma == 40.0
    end
  end

  describe "calculate_ema/2" do
    test "computes exponential moving average" do
      ema = Indicators.calculate_ema(@sample_prices, 10)
      assert is_float(ema)
      assert ema > 40.0 and ema < 50.0
    end
  end

  describe "calculate_rsi/2" do
    test "computes 14-period RSI" do
      rsi = Indicators.calculate_rsi(@sample_prices, 14)
      assert is_float(rsi)
      assert rsi >= 0.0 and rsi <= 100.0
    end
  end

  describe "calculate_macd/4" do
    test "computes MACD line, signal line, and histogram" do
      macd = Indicators.calculate_macd(@sample_prices, 12, 26, 9)
      assert is_map(macd)
      assert is_float(macd.macd_line)
      assert is_float(macd.signal_line)
      assert is_float(macd.histogram)
    end
  end

  describe "calculate_bollinger_bands/3" do
    test "computes upper, middle, and lower bands" do
      bb = Indicators.calculate_bollinger_bands(@sample_prices, 20, 2.0)
      assert is_map(bb)
      assert bb.upper_band > bb.middle_band
      assert bb.middle_band > bb.lower_band
      assert bb.bandwidth_pct > 0.0
    end
  end
end
