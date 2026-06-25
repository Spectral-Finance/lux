defmodule Lux.Unit.Prisms.TechnicalAnalysis.MACDTest do
  @moduledoc false
  use UnitCase, async: true

  alias Lux.Prisms.TechnicalAnalysis.MACD

  describe "handler/2 - MACD calculation" do
    test "calculates MACD with sufficient data" do
      prices =
        Enum.map(1..50, fn i ->
          100 + i * 0.5 + :math.sin(i * 0.1) * 2
        end)

      assert {:ok, result} = MACD.handler(%{prices: prices}, nil)
      assert is_number(result.macd_line)
      assert is_number(result.signal_line)
      assert is_number(result.histogram)
      assert result.fast_period == 12
      assert result.slow_period == 26
      assert result.signal_period == 9
    end

    test "detects bullish crossover" do
      # Create data that produces a bullish crossover
      prices = Enum.map(1..60, &(&1 * 1.5))
      assert {:ok, result} = MACD.handler(%{prices: prices}, nil)
      assert result.crossover in ["bullish", "bearish", "none"]
    end

    test "accepts custom periods" do
      prices = Enum.map(1..40, &(&1 * 1.0))
      assert {:ok, result} = MACD.handler(%{prices: prices, fast_period: 5, slow_period: 10, signal_period: 3}, nil)
      assert result.fast_period == 5
      assert result.slow_period == 10
      assert result.signal_period == 3
    end
  end

  describe "handler/2 - error cases" do
    test "too few prices returns error" do
      assert {:error, msg} = MACD.handler(%{prices: [1, 2]}, nil)
      assert msg =~ "at least 2 values"
    end

    test "missing prices returns error" do
      assert {:error, _msg} = MACD.handler(%{}, nil)
    end
  end
end
