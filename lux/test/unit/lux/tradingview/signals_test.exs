defmodule Lux.TradingView.SignalsTest do
  use UnitCase, async: true

  alias Lux.TradingView.Signals

  @sample_candles [
    %{open: 100.0, high: 105.0, low: 98.0, close: 102.0, volume: 1000},
    %{open: 102.0, high: 107.0, low: 101.0, close: 106.0, volume: 1200},
    %{open: 106.0, high: 108.0, low: 104.0, close: 105.0, volume: 800},
    %{open: 105.0, high: 110.0, low: 103.0, close: 109.0, volume: 1500},
    %{open: 109.0, high: 112.0, low: 107.0, close: 111.0, volume: 1400},
    %{open: 111.0, high: 115.0, low: 110.0, close: 114.0, volume: 1800},
    %{open: 114.0, high: 116.0, low: 112.0, close: 113.0, volume: 1100},
    %{open: 113.0, high: 114.0, low: 108.0, close: 109.0, volume: 1300},
    %{open: 109.0, high: 111.0, low: 106.0, close: 107.0, volume: 950},
    %{open: 107.0, high: 108.0, low: 102.0, close: 104.0, volume: 1600},
    %{open: 104.0, high: 106.0, low: 101.0, close: 103.0, volume: 1050},
    %{open: 103.0, high: 105.0, low: 99.0, close: 101.0, volume: 1250},
    %{open: 101.0, high: 103.0, low: 98.0, close: 100.0, volume: 1150},
    %{open: 100.0, high: 104.0, low: 99.0, close: 103.0, volume: 1350},
    %{open: 103.0, high: 107.0, low: 102.0, close: 106.0, volume: 1450}
  ]

  describe "generate_signal/1 and /5" do
    test "generates confluence score and valid trade recommendation from candles" do
      signal = Signals.generate_signal(@sample_candles)

      assert is_map(signal)
      assert is_integer(signal.score) or is_float(signal.score)
      assert signal.score >= -100 and signal.score <= 100
      assert signal.recommendation in [:strong_buy, :buy, :neutral, :sell, :strong_sell]
      assert signal.rsi_signal in [:bullish, :bearish, :neutral]
      assert signal.macd_signal in [:bullish, :bearish, :neutral]
      assert signal.bb_signal in [:bullish, :bearish, :neutral]
      assert signal.stoch_signal in [:bullish, :bearish, :neutral]
      assert signal.indicators_evaluated == 4
    end

    test "generates signal from explicit indicators" do
      signal =
        Signals.generate_signal(
          100.0,
          25.0,
          %{histogram: 1.2, trend: :bullish},
          %{upper: 110.0, lower: 95.0},
          %{k: 15.0}
        )

      assert signal.score > 0
      assert signal.recommendation in [:strong_buy, :buy]
      assert signal.rsi_signal == :bullish
      assert signal.macd_signal == :bullish
      assert signal.stoch_signal == :bullish
    end

    test "generates bearish signal on overbought conditions" do
      signal =
        Signals.generate_signal(
          150.0,
          85.0,
          %{histogram: -2.5, trend: :bearish},
          %{upper: 140.0, lower: 110.0},
          %{k: 92.0}
        )

      assert signal.score < 0
      assert signal.recommendation in [:strong_sell, :sell]
      assert signal.rsi_signal == :bearish
      assert signal.macd_signal == :bearish
    end
  end
end
