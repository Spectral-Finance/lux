defmodule Lux.Integrations.TradingView.AnalyzerTest do
  use UnitCase, async: true
  alias Lux.Integrations.TradingView.Analyzer

  describe "sma/2" do
    test "calculates simple moving average correctly" do
      assert Analyzer.sma([1, 2, 3, 4, 5], 3) == [2.0, 3.0, 4.0]
    end
    test "handles window equal to list length" do
      assert Analyzer.sma([1, 2, 3], 3) == [2.0]
    end
    test "returns empty list for window larger than data" do
      assert Analyzer.sma([1, 2], 5) == []
    end
    test "window of 1 returns original values" do
      assert Analyzer.sma([10, 20, 30], 1) == [10.0, 20.0, 30.0]
    end
    test "realistic price data" do
      prices = [100, 102, 101, 103, 105, 104, 106, 108, 107, 109]
      result = Analyzer.sma(prices, 5)
      assert length(result) == 6
      assert hd(result) == 102.2
    end
  end

  describe "ema/2" do
    test "calculates exponential moving average" do
      result = Analyzer.ema([1, 2, 3, 4, 5], 3)
      assert length(result) == 5
      assert hd(result) == 1.0
    end
    test "single element returns itself" do
      assert Analyzer.ema([42.0], 5) == [42.0]
    end
    test "constant values return same value" do
      assert Analyzer.ema([5.0, 5.0, 5.0, 5.0], 3) == [5.0, 5.0, 5.0, 5.0]
    end
  end

  describe "rsi/2" do
    test "returns 50.0 for insufficient data" do
      assert Analyzer.rsi([1, 2], 14) == 50.0
    end
    test "returns 100.0 for strictly increasing prices" do
      prices = Enum.to_list(1..20)
      assert Analyzer.rsi(prices, 14) == 100.0
    end
    test "returns 0.0 for strictly decreasing prices" do
      prices = Enum.to_list(20..1)
      assert Analyzer.rsi(prices, 14) == 0.0
    end
    test "returns reasonable value for mixed data" do
      prices = [100, 101, 102, 103, 104, 103, 102, 101, 100, 99]
      rsi = Analyzer.rsi(prices, 5)
      assert is_number(rsi)
      assert rsi >= 0 and rsi <= 100
    end
    test "default window is 14" do
      prices = Enum.to_list(1..30)
      assert is_number(Analyzer.rsi(prices))
    end
  end

  describe "macd/1" do
    test "returns map with required keys" do
      prices = Enum.to_list(1..30)
      result = Analyzer.macd(prices)
      assert is_map(result)
      assert Map.has_key?(result, :macd_line)
      assert Map.has_key?(result, :signal_line)
      assert Map.has_key?(result, :histogram)
    end
    test "has current values" do
      prices = Enum.to_list(1..50)
      result = Analyzer.macd(prices)
      assert is_number(result.current_macd)
      assert is_number(result.current_signal)
      assert is_number(result.current_histogram)
    end
    test "linear uptrend produces positive MACD" do
      prices = Enum.to_list(1..50)
      result = Analyzer.macd(prices)
      assert result.current_macd > 0
    end
  end

  describe "bollinger_bands/2" do
    test "returns map with required keys" do
      prices = Enum.to_list(1..30)
      result = Analyzer.bollinger_bands(prices)
      assert is_map(result)
      assert Map.has_key?(result, :upper)
      assert Map.has_key?(result, :middle)
      assert Map.has_key?(result, :lower)
    end
    test "upper band is always >= middle band" do
      prices = Enum.to_list(1..30)
      result = Analyzer.bollinger_bands(prices)
      Enum.zip(result.upper, result.middle)
      |> Enum.each(fn {upper, middle} -> assert upper >= middle end)
    end
    test "lower band is always <= middle band" do
      prices = Enum.to_list(1..30)
      result = Analyzer.bollinger_bands(prices)
      Enum.zip(result.lower, result.middle)
      |> Enum.each(fn {lower, middle} -> assert lower <= middle end)
    end
    test "has current values" do
      prices = Enum.to_list(1..30)
      result = Analyzer.bollinger_bands(prices)
      assert is_number(result.current_upper)
      assert is_number(result.current_middle)
      assert is_number(result.current_lower)
    end
    test "custom window and std dev multiplier" do
      prices = Enum.to_list(1..30)
      result = Analyzer.bollinger_bands(prices, 10, 1.5)
      assert is_number(result.current_upper)
    end
  end

  describe "adx/3" do
    test "returns map with required keys" do
      highs = [100, 102, 101, 103, 105, 104, 106, 108, 107, 109, 110, 109, 111, 112, 110]
      lows = [95, 96, 97, 95, 96, 98, 97, 99, 100, 98, 99, 101, 100, 101, 103]
      closes = [98, 100, 99, 102, 104, 103, 105, 107, 106, 108, 109, 108, 110, 111, 109]
      result = Analyzer.adx(highs, lows, closes)
      assert is_map(result)
      assert Map.has_key?(result, :adx)
      assert Map.has_key?(result, :di_plus)
      assert Map.has_key?(result, :di_minus)
      assert Map.has_key?(result, :current_adx)
      assert Map.has_key?(result, :trend_strength)
    end
    test "current_adx is a number" do
      highs = [100, 102, 101, 103, 105, 104, 106, 108, 107, 109, 110, 109, 111, 112, 110]
      lows = [95, 96, 97, 95, 96, 98, 97, 99, 100, 98, 99, 101, 100, 101, 103]
      closes = [98, 100, 99, 102, 104, 103, 105, 107, 106, 108, 109, 108, 110, 111, 109]
      result = Analyzer.adx(highs, lows, closes)
      assert is_number(result.current_adx)
    end
    test "trend_strength is a string" do
      highs = [100, 102, 101, 103, 105, 104, 106, 108, 107, 109, 110, 109, 111, 112, 110]
      lows = [95, 96, 97, 95, 96, 98, 97, 99, 100, 98, 99, 101, 100, 101, 103]
      closes = [98, 100, 99, 102, 104, 103, 105, 107, 106, 108, 109, 108, 110, 111, 109]
      result = Analyzer.adx(highs, lows, closes)
      assert is_binary(result.trend_strength)
    end
  end

  describe "generate_signal/1" do
    test "returns error for insufficient data" do
      assert Analyzer.generate_signal(%{prices: [1, 2, 3]}) ==
               {:error, "Insufficient data: need at least 30 price points, got 3"}
    end
    test "returns error for invalid input" do
      assert Analyzer.generate_signal(%{}) ==
               {:error, "Invalid input: expected a map with :prices key"}
    end
    test "returns ok with valid signal for 30 prices" do
      prices = Enum.to_list(1..30)
      {:ok, signal} = Analyzer.generate_signal(%{prices: prices})
      assert is_map(signal)
      assert Map.has_key?(signal, :signal)
      assert Map.has_key?(signal, :strength)
      assert Map.has_key?(signal, :details)
      assert signal.signal in ["strong_buy", "buy", "hold", "sell", "strong_sell"]
      assert signal.strength >= 0 and signal.strength <= 1
    end
    test "returns correct signal for uptrend" do
      prices = Enum.to_list(1..50)
      highs = Enum.map(prices, & &1 + 1)
      lows = Enum.map(prices, & &1 - 1)
      {:ok, signal} = Analyzer.generate_signal(%{prices: prices, highs: highs, lows: lows})
      assert signal.signal in ["buy", "strong_buy"]
      assert signal.strength > 0
    end
    test "returns correct signal for downtrend" do
      prices = Enum.to_list(50..1)
      highs = Enum.map(prices, & &1 + 1)
      lows = Enum.map(prices, & &1 - 1)
      {:ok, signal} = Analyzer.generate_signal(%{prices: prices, highs: highs, lows: lows})
      assert signal.signal in ["sell", "strong_sell"]
      assert signal.strength > 0
    end
    test "includes detailed indicator data" do
      prices = Enum.to_list(1..50)
      highs = Enum.map(prices, & &1 + 1)
      lows = Enum.map(prices, & &1 - 1)
      {:ok, signal} = Analyzer.generate_signal(%{prices: prices, highs: highs, lows: lows, timeframe: "1h"})
      details = signal.details
      assert Map.has_key?(details, :scores)
      assert Map.has_key?(details, :rsi)
      assert Map.has_key?(details, :macd)
      assert Map.has_key?(details, :bollinger)
      assert Map.has_key?(details, :adx)
      assert Map.has_key?(details, :sma)
      assert details.timeframe == "1h"
    end
    test "works without highs/lows (ADX fallback)" do
      prices = Enum.to_list(1..50)
      {:ok, signal} = Analyzer.generate_signal(%{prices: prices})
      assert signal.signal in ["strong_buy", "buy", "hold", "sell", "strong_sell"]
      assert is_number(signal.details.rsi)
      assert is_map(signal.details.macd)
      assert is_map(signal.details.bollinger)
      assert is_map(signal.details.adx)
    end
    test "sideways market produces hold signal" do
      sideways = Enum.flat_map(1..25, fn i -> [i, i + 0.1] end)
      {:ok, signal} = Analyzer.generate_signal(%{prices: sideways})
      assert signal.signal == "hold"
      assert signal.strength < 0.15
    end
  end

  describe "edge cases" do
    test "empty prices returns error" do
      assert Analyzer.generate_signal(%{prices: []}) ==
               {:error, "Insufficient data: need at least 30 price points, got 0"}
    end
    test "single price point returns error" do
      assert Analyzer.generate_signal(%{prices: [100]}) ==
               {:error, "Insufficient data: need at least 30 price points, got 1"}
    end
    test "exactly 30 prices works" do
      prices = Enum.to_list(1..30)
      {:ok, signal} = Analyzer.generate_signal(%{prices: prices})
      assert signal.signal in ["strong_buy", "buy", "hold", "sell", "strong_sell"]
    end
  end
end
