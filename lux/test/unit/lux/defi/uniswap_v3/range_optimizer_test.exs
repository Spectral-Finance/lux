defmodule Lux.Defi.UniswapV3.RangeOptimizerTest do
  use ExUnit.Case, async: true

  alias Lux.Defi.UniswapV3.RangeOptimizer

  describe "calculate_range/4" do
    test "calculates aligned ticks for moderate strategy" do
      current_tick = 200_000
      fee = 3000

      assert {:ok, range} = RangeOptimizer.calculate_range(current_tick, fee, :moderate)
      assert range.tick_lower < current_tick
      assert range.tick_upper > current_tick
      assert rem(range.tick_lower, 60) == 0
      assert rem(range.tick_upper, 60) == 0
      assert range.efficiency > 1.0
    end

    test "calculates narrower range with higher efficiency for narrow strategy" do
      current_tick = 200_000
      fee = 3000

      {:ok, moderate} = RangeOptimizer.calculate_range(current_tick, fee, :moderate)
      {:ok, narrow} = RangeOptimizer.calculate_range(current_tick, fee, :narrow)

      assert (narrow.tick_upper - narrow.tick_lower) < (moderate.tick_upper - moderate.tick_lower)
      assert narrow.efficiency > moderate.efficiency
    end
  end

  describe "calculate_capital_efficiency/2" do
    test "returns expected multiplier for given bounds" do
      # For a tight +/- 5% range around 1.0 (0.95 to 1.05)
      eff = RangeOptimizer.calculate_capital_efficiency(0.95, 1.05)
      assert eff >= 20.0
    end
  end
end
