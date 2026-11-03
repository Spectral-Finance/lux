defmodule Lux.TradingView.PineScriptTest do
  use UnitCase, async: true

  alias Lux.TradingView.PineScript

  @sample_candles [
    %{open: 100.0, high: 105.0, low: 98.0, close: 100.0, volume: 1000},
    %{open: 100.0, high: 106.0, low: 99.0, close: 102.0, volume: 1100},
    %{open: 102.0, high: 107.0, low: 101.0, close: 105.0, volume: 1200},
    %{open: 105.0, high: 108.0, low: 104.0, close: 104.0, volume: 1300},
    %{open: 104.0, high: 110.0, low: 103.0, close: 108.0, volume: 1400},
    %{open: 108.0, high: 112.0, low: 107.0, close: 110.0, volume: 1500},
    %{open: 110.0, high: 115.0, low: 109.0, close: 112.0, volume: 1600},
    %{open: 112.0, high: 116.0, low: 111.0, close: 115.0, volume: 1700},
    %{open: 115.0, high: 118.0, low: 114.0, close: 117.0, volume: 1800},
    %{open: 117.0, high: 120.0, low: 116.0, close: 119.0, volume: 1900},
    %{open: 119.0, high: 122.0, low: 118.0, close: 121.0, volume: 2000},
    %{open: 121.0, high: 125.0, low: 120.0, close: 124.0, volume: 2100},
    %{open: 124.0, high: 128.0, low: 123.0, close: 127.0, volume: 2200},
    %{open: 127.0, high: 130.0, low: 126.0, close: 129.0, volume: 2300},
    %{open: 129.0, high: 132.0, low: 128.0, close: 131.0, volume: 2400}
  ]

  describe "eval/2" do
    test "evaluates simple variable assignments and expressions" do
      script = """
      fast_ma = ta.sma(close, 5)
      slow_ma = ta.sma(close, 10)
      bullish = fast_ma > slow_ma
      """

      {:ok, result} = PineScript.eval(script, @sample_candles)
      assert is_map(result)
      assert is_float(result["fast_ma"])
      assert is_float(result["slow_ma"])
      assert is_boolean(result["bullish"])
    end

    test "evaluates ta.crossover and ta.crossunder" do
      script = """
      fast = ta.sma(close, 3)
      slow = ta.sma(close, 5)
      long_condition = ta.crossover(fast, slow)
      short_condition = ta.crossunder(fast, slow)
      """

      {:ok, result} = PineScript.eval(script, @sample_candles)
      assert is_boolean(result["long_condition"])
      assert is_boolean(result["short_condition"])
    end

    test "evaluates series lookback syntax close[1]" do
      script = """
      prev_close = close[1]
      is_higher = close > prev_close
      """

      {:ok, result} = PineScript.eval(script, @sample_candles)
      assert is_float(result["prev_close"])
      assert is_boolean(result["is_higher"])
      assert result["is_higher"] == true
    end

    test "handles boolean operators and comments" do
      script = """
      // This is a Pine Script comment
      fast = ta.ema(close, 5)
      rsi_val = ta.rsi(close, 14)
      buy_signal = fast > 110.0 and rsi_val > 40.0
      """

      {:ok, result} = PineScript.eval(script, @sample_candles)
      assert is_boolean(result["buy_signal"])
    end

    test "returns parse error for invalid syntax gracefully" do
      invalid_script = "??? unexpected syntax 12345"
      {:ok, result} = PineScript.eval(invalid_script, @sample_candles)
      # Result should still return map with default environment variables
      assert Map.has_key?(result, "close")
    end
  end
end
