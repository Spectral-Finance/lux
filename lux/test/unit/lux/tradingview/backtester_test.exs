defmodule Lux.TradingView.BacktesterTest do
  use UnitCase, async: true

  alias Lux.TradingView.Backtester

  describe "run_backtest/3" do
    test "simulates trades and produces performance statistics" do
      # Generate upward trending sample prices with oscillations
      prices =
        Enum.map(1..100, fn i ->
          50.0 + i * 0.5 + :math.sin(i / 5.0) * 5.0
        end)

      stats = Backtester.run_backtest(prices, 5, 15)

      assert is_integer(stats.total_trades)
      assert is_float(stats.win_rate_pct)
      assert is_float(stats.total_return_pct)
      assert is_float(stats.profit_factor)
      assert is_float(stats.max_drawdown_pct)
    end
  end
end
