defmodule Lux.Unit.Prisms.TechnicalAnalysis.MovingAverageTest do
  @moduledoc false
  use UnitCase, async: true

  alias Lux.Prisms.TechnicalAnalysis.MovingAverage

  describe "handler/2 - SMA calculation" do
    test "calculates SMA correctly" do
      prices = [10, 20, 30, 40, 50]
      assert {:ok, result} = MovingAverage.handler(%{prices: prices, type: "sma", period: 3}, nil)
      assert result.type == "sma"
      assert result.period == 3
      assert is_number(result.ma_value)
      assert result.trend in ["uptrend", "downtrend", "neutral"]
    end

    test "calculates EMA correctly" do
      prices = [10, 20, 30, 40, 50]
      assert {:ok, result} = MovingAverage.handler(%{prices: prices, type: "ema", period: 3}, nil)
      assert result.type == "ema"
      assert result.period == 3
      assert is_number(result.ma_value)
    end

    test "detects uptrend" do
      prices = Enum.map(1..30, &(&1 * 1.0))
      assert {:ok, result} = MovingAverage.handler(%{prices: prices, type: "sma", period: 10}, nil)
      assert result.trend == "uptrend"
    end

    test "detects downtrend" do
      prices = Enum.map(30..1, &(&1 * 1.0))
      assert {:ok, result} = MovingAverage.handler(%{prices: prices, type: "sma", period: 10}, nil)
      assert result.trend == "downtrend"
    end
  end

  describe "handler/2 - error cases" do
    test "empty prices returns error" do
      assert {:error, msg} = MovingAverage.handler(%{prices: []}, nil)
      assert msg =~ "must not be empty"
    end
  end
end
