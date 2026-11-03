defmodule Lux.TradingView.SignalsTest do
  use UnitCase, async: true

  alias Lux.TradingView.Signals

  describe "generate_signal/4" do
    test "identifies strong buy on oversold bounce" do
      # Oversold RSI (25), Bullish MACD, lower band bounce
      macd = %{macd_line: 0.5, histogram: 0.2}
      bb = %{lower_band: 100.0, upper_band: 120.0, middle_band: 110.0}

      sig = Signals.generate_signal(99.5, 25.0, macd, bb)

      assert sig.score >= 60
      assert sig.recommendation == :strong_buy
      assert sig.rsi_signal == :oversold
      assert sig.bb_signal == :bounce_buy
    end

    test "identifies strong sell on overbought rejection" do
      macd = %{macd_line: -0.5, histogram: -0.2}
      bb = %{lower_band: 100.0, upper_band: 120.0, middle_band: 110.0}

      sig = Signals.generate_signal(121.0, 75.0, macd, bb)

      assert sig.score <= -60
      assert sig.recommendation == :strong_sell
      assert sig.rsi_signal == :overbought
      assert sig.bb_signal == :rejection_sell
    end

    test "identifies neutral on mixed conditions" do
      sig = Signals.generate_signal(105.0, 50.0, nil, nil)
      assert sig.score == 0
      assert sig.recommendation == :neutral
    end
  end
end
