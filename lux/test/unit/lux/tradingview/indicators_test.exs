defmodule Lux.TradingView.IndicatorsTest do
  use UnitCase, async: true

  alias Lux.TradingView.Indicators

  @sample_closes [
    44.34,
    44.09,
    44.15,
    43.61,
    44.33,
    44.83,
    45.10,
    45.42,
    45.84,
    46.08,
    45.89,
    46.03,
    45.61,
    46.28,
    46.28,
    46.00,
    46.03,
    46.41,
    46.22,
    45.64
  ]

  @sample_ohlcv [
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

  describe "sma/2" do
    test "calculates simple moving average correctly" do
      data = [10.0, 20.0, 30.0, 40.0, 50.0]
      {:ok, result} = Indicators.sma(data, 3)

      assert length(result) == 3
      assert_in_delta Enum.at(result, 0), 20.0, 0.001
      assert_in_delta Enum.at(result, 1), 30.0, 0.001
      assert_in_delta Enum.at(result, 2), 40.0, 0.001
    end

    test "returns error on insufficient data" do
      assert {:error, _} = Indicators.sma([10.0, 20.0], 5)
    end
  end

  describe "ema/2" do
    test "calculates exponential moving average" do
      {:ok, result} = Indicators.ema(@sample_closes, 10)
      assert length(result) == length(@sample_closes) - 10 + 1
      assert is_float(hd(result))
      assert is_float(List.last(result))
    end
  end

  describe "rsi/2" do
    test "calculates RSI with Wilder smoothing" do
      {:ok, result} = Indicators.rsi(@sample_closes, 14)
      assert length(result) > 0
      last_rsi = List.last(result)
      assert last_rsi >= 0.0 and last_rsi <= 100.0
    end

    test "handles flat values returning 50.0" do
      flat = List.duplicate(100.0, 20)
      {:ok, result} = Indicators.rsi(flat, 14)
      assert List.last(result) == 50.0
    end
  end

  describe "macd/4" do
    test "calculates MACD line, signal line and histogram" do
      {:ok, macd} = Indicators.macd(@sample_closes, 5, 10, 3)
      assert is_list(macd.macd)
      assert is_list(macd.signal)
      assert is_list(macd.histogram)
      assert length(macd.histogram) > 0

      assert_in_delta List.last(macd.macd) - List.last(macd.signal),
                      List.last(macd.histogram),
                      0.001
    end
  end

  describe "bollinger_bands/3" do
    test "calculates middle, upper, lower, percent_b and bandwidth" do
      {:ok, bb} = Indicators.bollinger_bands(@sample_closes, 10, 2.0)
      assert is_list(bb.middle)
      assert is_list(bb.upper)
      assert is_list(bb.lower)
      assert is_list(bb.percent_b)
      assert is_list(bb.bandwidth)

      last_upper = List.last(bb.upper)
      last_middle = List.last(bb.middle)
      last_lower = List.last(bb.lower)

      assert last_upper >= last_middle
      assert last_middle >= last_lower
    end
  end

  describe "atr/2" do
    test "calculates average true range from candles" do
      {:ok, result} = Indicators.atr(@sample_ohlcv, 5)
      assert length(result) > 0
      assert Enum.all?(result, &(&1 > 0.0))
    end
  end

  describe "stochastic/4" do
    test "calculates %K and %D lines" do
      {:ok, stoch} = Indicators.stochastic(@sample_ohlcv, 5, 3, 3)
      assert is_list(stoch.k)
      assert is_list(stoch.d)
      assert length(stoch.k) > 0
      assert Enum.all?(stoch.k, &(&1 >= 0.0 and &1 <= 100.0))
    end
  end

  describe "supertrend/3" do
    test "calculates supertrend line and direction" do
      {:ok, st} = Indicators.supertrend(@sample_ohlcv, 5, 3.0)
      assert is_list(st.supertrend)
      assert is_list(st.direction)
      assert length(st.supertrend) == length(@sample_ohlcv)
      assert List.last(st.direction) in [1, -1]
    end
  end

  describe "calculate_all/2" do
    test "computes comprehensive technical analysis summary" do
      {:ok, analysis} = Indicators.calculate_all(@sample_ohlcv)
      assert is_map(analysis)
      assert is_float(analysis[:rsi])
      assert is_map(analysis[:macd])
      assert is_map(analysis[:bollinger])
      assert is_float(analysis[:sma_20]) or is_nil(analysis[:sma_20])
      assert is_float(analysis[:ema_20]) or is_nil(analysis[:ema_20])
    end
  end
end
