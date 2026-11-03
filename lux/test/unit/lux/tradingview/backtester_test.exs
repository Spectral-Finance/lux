defmodule Lux.TradingView.BacktesterTest do
  use UnitCase, async: true

  alias Lux.TradingView.Backtester

  # Generate 50 oscillating price points to test crossovers and reversals
  @sample_candles Enum.map(1..50, fn i ->
                    angle = i * 0.3
                    price = 100.0 + :math.sin(angle) * 15.0 + i * 0.5

                    %{
                      open: price - 0.5,
                      high: price + 1.0,
                      low: price - 1.0,
                      close: price,
                      volume: 1000 + i * 10
                    }
                  end)

  describe "run_backtest/3 with :ma_crossover" do
    test "simulates trades and computes performance metrics" do
      result = Backtester.run_backtest(@sample_candles, :ma_crossover, %{fast_ma: 5, slow_ma: 12})

      assert result.strategy == :ma_crossover
      assert is_integer(result.total_trades)
      assert is_integer(result.winning_trades)
      assert is_integer(result.losing_trades)
      assert is_float(result.win_rate_pct)
      assert is_float(result.total_return_pct)
      assert is_float(result.max_drawdown_pct)
      assert is_list(result.trades)
    end
  end

  describe "run_backtest/3 with :rsi_reversal" do
    test "simulates RSI mean-reversion trades" do
      result =
        Backtester.run_backtest(@sample_candles, :rsi_reversal, %{
          rsi_period: 10,
          oversold: 40.0,
          overbought: 60.0
        })

      assert result.strategy == :rsi_reversal
      assert is_integer(result.total_trades)
      assert is_float(result.win_rate_pct)
      assert is_list(result.trades)
    end
  end

  describe "run_backtest/3 with :bollinger_breakout" do
    test "simulates Bollinger Band breakouts" do
      result =
        Backtester.run_backtest(@sample_candles, :bollinger_breakout, %{
          period: 15,
          multiplier: 1.5
        })

      assert result.strategy == :bollinger_breakout
      assert is_integer(result.total_trades)
      assert is_float(result.win_rate_pct)
      assert is_list(result.trades)
    end
  end

  describe "run_backtest/3 fallback" do
    test "returns empty zero-trade result for insufficient data" do
      result = Backtester.run_backtest([100.0, 101.0], :ma_crossover)
      assert result.total_trades == 0
      assert result.win_rate_pct == 0.0
      assert result.trades == []
    end
  end
end
