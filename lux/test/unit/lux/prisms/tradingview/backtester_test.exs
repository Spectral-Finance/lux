defmodule Lux.Prisms.TradingView.BacktesterTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.TradingView.Backtester

  @sample_candles (for i <- 0..99 do
                     base = 100.0 + :math.sin(i / 10.0) * 20 + i * 0.1
                     %{
                       open: base - 0.5,
                       high: base + 2.0,
                       low: base - 2.0,
                       close: base,
                       volume: 1000 + rem(i * 7, 500),
                       timestamp: 1_704_067_200_000 + i * 3_600_000
                     }
                   end)

  describe "run/1 with SMA crossover" do
    test "returns valid backtest results" do
      assert {:ok, result} =
               Backtester.run(%{
                 candles: @sample_candles,
                 strategy: "sma_cross",
                 params: %{fast: 5, slow: 15},
                 initial_capital: 10_000.0,
                 commission: 0.001
               })

      assert is_number(result.total_return)
      assert is_number(result.win_rate)
      assert result.win_rate >= 0.0 and result.win_rate <= 100.0
      assert is_integer(result.total_trades)
      assert result.total_trades >= 0
      assert is_number(result.max_drawdown)
      assert result.max_drawdown >= 0.0
      assert is_number(result.sharpe_ratio)
      assert result.strategy == "sma_cross"
      assert result.candle_count == 100
    end

    test "trades list contains valid entries" do
      {:ok, result} =
        Backtester.run(%{
          candles: @sample_candles,
          strategy: "sma_cross",
          params: %{fast: 5, slow: 15}
        })

      if result.total_trades > 0 do
        [trade | _] = result.trades
        assert Map.has_key?(trade, :entry_price)
        assert Map.has_key?(trade, :exit_price)
        assert Map.has_key?(trade, :pnl)
        assert Map.has_key?(trade, :return_pct)
        assert Map.has_key?(trade, :commission)
      end
    end
  end

  describe "run/1 with RSI reversal" do
    test "returns valid results" do
      assert {:ok, result} =
               Backtester.run(%{
                 candles: @sample_candles,
                 strategy: "rsi_reversal",
                 params: %{period: 14, oversold: 30, overbought: 70}
               })

      assert is_number(result.total_return)
      assert result.strategy == "rsi_reversal"
    end
  end

  describe "run/1 with MACD signal" do
    test "returns valid results" do
      assert {:ok, result} =
               Backtester.run(%{
                 candles: @sample_candles,
                 strategy: "macd_signal",
                 params: %{fast: 12, slow: 26, signal: 9}
               })

      assert is_number(result.total_return)
      assert result.strategy == "macd_signal"
    end
  end

  describe "run/1 with Bollinger bounce" do
    test "returns valid results" do
      assert {:ok, result} =
               Backtester.run(%{
                 candles: @sample_candles,
                 strategy: "bollinger_bounce",
                 params: %{period: 20, std_dev: 2.0}
               })

      assert is_number(result.total_return)
      assert result.strategy == "bollinger_bounce"
    end
  end

  describe "error handling" do
    test "returns error with insufficient candles" do
      assert {:error, _msg} =
               Backtester.run(%{
                 candles: [%{close: 100.0}],
                 strategy: "sma_cross"
               })
    end

    test "returns error with empty candles" do
      assert {:error, _msg} =
               Backtester.run(%{
                 candles: [],
                 strategy: "sma_cross"
               })
    end
  end

  describe "default parameters" do
    test "works without explicit params" do
      assert {:ok, result} =
               Backtester.run(%{
                 candles: @sample_candles,
                 strategy: "sma_cross"
               })

      assert result.candle_count == 100
    end
  end
end
