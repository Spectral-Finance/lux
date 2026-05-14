defmodule Lux.Prisms.TradingView.BacktestStrategyTest do
  use UnitCase, async: true

  alias Lux.Prisms.TradingView.BacktestStrategy

  test "returns strategy backtest" do
    bars = for i <- 1..30, do: %{time: i, open: i, high: i + 1, low: i - 1, close: i, volume: 1}

    assert {:ok, result} =
             BacktestStrategy.handler(%{bars: bars, fast_period: 2, slow_period: 4}, nil)

    assert result.trade_count >= 1
  end
end
