defmodule Lux.Unit.Prisms.TechnicalAnalysis.BollingerBandsTest do
  @moduledoc false
  use UnitCase, async: true

  alias Lux.Prisms.TechnicalAnalysis.BollingerBands

  describe "handler/2 - Bollinger Bands calculation" do
    test "calculates bands correctly" do
      prices = Enum.map(1..30, &(&1 * 1.0))
      assert {:ok, result} = BollingerBands.handler(%{prices: prices}, nil)
      assert result.upper_band > result.middle_band
      assert result.middle_band > result.lower_band
      assert result.bandwidth > 0
      assert result.pct_b >= 0 and result.pct_b <= 1
    end

    test "detects price above upper band" do
      prices = Enum.map(1..25, &(&1 * 1.0)) ++ [100.0, 101.0, 102.0]
      assert {:ok, result} = BollingerBands.handler(%{prices: prices}, nil)
      assert result.signal == "above_upper"
    end

    test "detects price below lower band" do
      prices = Enum.map(1..25, &(&1 * 1.0)) ++ [0.0, -1.0, -2.0]
      assert {:ok, result} = BollingerBands.handler(%{prices: prices}, nil)
      assert result.signal == "below_lower"
    end

    test "accepts custom period and std_dev" do
      prices = Enum.map(1..30, &(&1 * 1.0))
      assert {:ok, result} = BollingerBands.handler(%{prices: prices, period: 10, std_dev: 1.5}, nil)
      assert result.period == 10
      assert is_number(result.upper_band)
    end
  end

  describe "handler/2 - error cases" do
    test "empty prices returns error" do
      assert {:error, msg} = BollingerBands.handler(%{prices: []}, nil)
      assert msg =~ "must not be empty"
    end
  end
end
