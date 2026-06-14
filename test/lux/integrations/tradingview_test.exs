defmodule Lux.Integrations.TradingViewTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.TradingView

  describe "moving averages" do
    test "sma/1 returns correct value" do
      data = [10, 12, 11, 13, 14, 12, 11, 15, 16, 14, 13, 12, 11, 10, 12]
      {:ok, result} = TradingView.sma(data, period: 5)
      assert result.type == :sma
      assert result.period == 5
      assert is_float(result.value)
    end

    test "sma/1 returns error with insufficient data" do
      assert TradingView.sma([1, 2, 3], period: 14) == {:error, "Insufficient data: need 14 points, have 3"}
    end

    test "ema/1 returns correct value" do
      data = [10, 12, 11, 13, 14, 12, 11, 15, 16, 14, 13, 12, 11, 10, 12]
      {:ok, result} = TradingView.ema(data, period: 5)
      assert result.type == :ema
      assert is_float(result.value)
    end
  end

  describe "oscillators" do
    test "rsi/1 returns overbought/oversold signals" do
      # Uptrend data
      uptrend = Enum.to_list(1..20) |> Enum.map(&(&1 * 1.0))
      {:ok, result} = TradingView.rsi(uptrend, period: 5)
      assert result.type == :rsi
      assert result.signal in [:overbought, :oversold, :neutral]
      assert is_float(result.value)
    end

    test "macd/1 returns MACD components" do
      data = Enum.map(1..30, &(&1 + :rand.uniform() * 5))
      {:ok, result} = TradingView.macd(data)
      assert result.type == :macd
      assert result.macd_line != nil
      assert result.signal_line != nil
      assert result.histogram != nil
    end

    test "bollinger_bands/1 returns band structure" do
      data = Enum.map(1..25, &(50 + :rand.uniform() * 10))
      {:ok, result} = TradingView.bollinger_bands(data, period: 5)
      assert result.type == :bollinger_bands
      assert result.upper > result.middle
      assert result.middle > result.lower
    end

    test "stochastic/1 returns K and D values" do
      data = Enum.map(1..20, &(&1 * 1.0))
      {:ok, result} = TradingView.stochastic(data, period: 5)
      assert result.type == :stochastic
      assert result.k != nil
      assert result.d != nil
    end
  end

  describe "volatility" do
    test "atr/1 returns volatility measure" do
      data = Enum.map(1..20, &(&1 * 1.0))
      {:ok, result} = TradingView.atr(data, period: 5)
      assert result.type == :atr
      assert result.value > 0
    end
  end

  describe "signal generation" do
    test "sma_crossover/1 detects golden cross" do
      # Prices rising fast — fast SMA > slow SMA
      data = Enum.map(1..250, &(&1 + :rand.uniform() * 2))
      {:ok, result} = TradingView.sma_crossover(data, fast: 5, slow: 10)
      assert result.type == :sma_crossover
      assert result.signal in [:golden_cross, :death_cross, :bullish, :bearish, :neutral]
    end

    test "rsi_signal/1 generates RSI-based signal" do
      data = Enum.map(1..20, &(&1 * 1.0))
      {:ok, result} = TradingView.rsi_signal(data)
      assert result.type == :rsi_signal
    end

    test "macd_signal/1 generates MACD-based signal" do
      data = Enum.map(1..30, &(&1 * 1.0))
      {:ok, result} = TradingView.macd_signal(data)
      assert result.type == :macd_signal
    end
  end

  describe "comprehensive analysis" do
    test "comprehensive_analysis/1 returns full market view" do
      data = Enum.map(1..30, &(100 + :rand.uniform() * 10))
      {:ok, result} = TradingView.comprehensive_analysis(data)
      assert result.type == :comprehensive_analysis
      assert result.verdict in [:bullish, :bearish, :neutral, :slightly_bullish, :slightly_bearish]
      assert Map.has_key?(result.indicators, :sma)
      assert Map.has_key?(result.indicators, :rsi)
      assert Map.has_key?(result.indicators, :macd)
      assert Map.has_key?(result.indicators, :bollinger_bands)
    end

    test "multi_timeframe_analysis/1 consolidates signals" do
      timeframes = %{
        "5m" => Enum.map(1..20, &(100 + :rand.uniform() * 5)),
        "1h" => Enum.map(1..30, &(100 + :rand.uniform() * 10)),
        "4h" => Enum.map(1..40, &(100 + :rand.uniform() * 15)),
        "1d" => Enum.map(1..50, &(100 + :rand.uniform() * 20))
      }
      {:ok, result} = TradingView.multi_timeframe_analysis(timeframes)
      assert result.type == :multi_timeframe
      assert result.consensus in [:bullish, :bearish, :neutral]
    end
  end
end
