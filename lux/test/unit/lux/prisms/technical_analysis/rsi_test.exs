defmodule Lux.Unit.Prisms.TechnicalAnalysis.RSITest do
  @moduledoc false
  use UnitCase, async: true

  alias Lux.Prisms.TechnicalAnalysis.RSI

  describe "handler/2 - basic RSI calculation" do
    test "calculates RSI for upward trending prices" do
      prices = [42, 43, 44, 45, 46, 47, 48, 49, 50, 51]
      assert {:ok, result} = RSI.handler(%{prices: prices}, nil)
      assert result.rsi > 50
      assert result.signal == "neutral"
      assert result.period == 14
      assert is_list(result.rsi_series)
    end

    test "calculates RSI for downward trending prices" do
      prices = [50, 49, 48, 47, 46, 45, 44, 43, 42, 41]
      assert {:ok, result} = RSI.handler(%{prices: prices}, nil)
      assert result.rsi < 50
      assert result.signal == "neutral"
    end

    test "detects overbought condition" do
      # Strong uptrend to push RSI above 70
      prices = Enum.map(1..20, &(&1 * 2 + 100))
      assert {:ok, result} = RSI.handler(%{prices: prices}, nil)
      assert result.rsi > 70
      assert result.signal == "overbought"
    end

    test "detects oversold condition" do
      # Strong downtrend to push RSI below 30
      prices = Enum.map(1..20, &(120 - &1 * 2))
      assert {:ok, result} = RSI.handler(%{prices: prices}, nil)
      assert result.rsi < 30
      assert result.signal == "oversold"
    end

    test "accepts custom period" do
      prices = [40, 41, 42, 43, 44, 45, 46, 47, 48, 49]
      assert {:ok, result} = RSI.handler(%{prices: prices, period: 5}, nil)
      assert result.period == 5
      assert is_number(result.rsi)
    end
  end

  describe "handler/2 - error cases" do
    test "empty prices returns error" do
      assert {:error, msg} = RSI.handler(%{prices: []}, nil)
      assert msg =~ "must not be empty"
    end

    test "missing prices returns error" do
      assert {:error, _msg} = RSI.handler(%{}, nil)
    end
  end

  describe "calculate_rsi_series/2" do
    test "short series returns single value" do
      prices = [1, 2, 3]
      result = RSI.calculate_rsi_series(prices, 14)
      assert result == [50.0]
    end

    test "series longer than period calculates multiple values" do
      prices = Enum.map(1..30, &(&1 * 1.0))
      result = RSI.calculate_rsi_series(prices, 14)
      assert length(result) > 1
      assert Enum.all?(result, &is_number/1)
    end
  end
end
