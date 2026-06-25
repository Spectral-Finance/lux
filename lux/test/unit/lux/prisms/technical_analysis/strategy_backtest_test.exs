defmodule Lux.Unit.Prisms.TechnicalAnalysis.StrategyBacktestTest do
  @moduledoc false
  use UnitCase, async: true

  alias Lux.Prisms.TechnicalAnalysis.StrategyBacktest

  describe "handler/2 - SMA Crossover backtest" do
    test "runs SMA crossover backtest" do
      prices = Enum.map(1..50, &(&1 * 1.0 + :rand.uniform(5)))
      assert {:ok, result} = StrategyBacktest.handler(%{
        prices: prices,
        strategy: "sma_crossover",
        fast_period: 5,
        slow_period: 10,
        initial_capital: 10000
      }, nil)

      assert result.strategy == "sma_crossover"
      assert result.initial_capital == 10000
      assert is_number(result.final_capital)
      assert is_number(result.total_return_pct)
      assert is_integer(result.num_trades)
      assert result.num_trades >= 0
      assert is_number(result.win_rate)
    end

    test "runs RSI backtest" do
      prices = Enum.map(1..50, &(&1 * 1.0 + :rand.uniform(5)))
      assert {:ok, result} = StrategyBacktest.handler(%{
        prices: prices,
        strategy: "rsi",
        initial_capital: 5000
      }, nil)

      assert result.strategy == "rsi"
      assert result.initial_capital == 5000
      assert is_number(result.final_capital)
    end
  end

  describe "handler/2 - error cases" do
    test "too few prices returns error" do
      assert {:error, msg} = StrategyBacktest.handler(%{prices: [1, 2, 3]}, nil)
      assert msg =~ "at least 10 values"
    end
  end
end
