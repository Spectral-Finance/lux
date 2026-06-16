defmodule Lux.Prisms.TradingView.BacktestSmaCrossTest do
  use UnitCase, async: true

  alias Lux.Prisms.TradingView.BacktestSmaCross

  @candles Enum.map(1..8, fn index ->
             %{time: index, open: index, high: index, low: index, close: index, volume: 100}
           end)

  test "returns SMA cross backtest through the prism" do
    assert {:ok, %{backtest: backtest}} =
             BacktestSmaCross.handler(%{candles: @candles, fast_period: 2, slow_period: 4}, nil)

    assert backtest.strategy == "sma_cross"
    assert length(backtest.trades) == 8
  end
end
