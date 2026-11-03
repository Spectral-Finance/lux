defmodule Lux.TradingView.Backtester do
  @moduledoc """
  Strategy backtesting simulation engine for TradingView technical indicators:
  - Simulates buy/sell executions on historical candle data
  - Computes Win Rate %, Total Return %, Profit Factor, and Max Drawdown %
  """

  @doc """
  Runs backtest simulation on historical price candles.
  """
  @spec run_backtest(list(number()), pos_integer(), pos_integer()) :: %{
          total_trades: non_neg_integer(),
          win_rate_pct: float(),
          total_return_pct: float(),
          profit_factor: float(),
          max_drawdown_pct: float()
        }
  def run_backtest(prices, fast_ma \\ 9, slow_ma \\ 21) when is_list(prices) and length(prices) > slow_ma do
    # Simple MA crossover strategy simulation
    trades =
      prices
      |> Enum.chunk_every(slow_ma + 1, 1, :discard)
      |> Enum.map(fn window ->
        p_curr = List.last(window)
        fast = Enum.take(window, -fast_ma) |> Enum.sum() |> Kernel./(fast_ma)
        slow = Enum.sum(window) / length(window)

        # Bullish if fast > slow
        {p_curr, fast > slow}
      end)

    # Convert state transitions into trade returns
    {_final_pos, _entry_p, returns} =
      Enum.reduce(trades, {:flat, 0.0, []}, fn {price, bullish?}, {pos, entry, rets} ->
        case {pos, bullish?} do
          {:flat, true} ->
            {:long, price, rets}

          {:long, false} ->
            ret = (price - entry) / entry * 100.0
            {:flat, 0.0, [ret | rets]}

          _ ->
            {pos, entry, rets}
        end
      end)

    wins = Enum.filter(returns, &(&1 > 0))
    losses = Enum.filter(returns, &(&1 <= 0))
    total_trades = length(returns)

    win_rate = if total_trades > 0, do: Float.round(length(wins) / total_trades * 100.0, 2), else: 0.0
    total_return = returns |> Enum.sum() |> Float.round(2)

    gross_profit = wins |> Enum.sum()
    gross_loss = losses |> Enum.map(&abs/1) |> Enum.sum()

    profit_factor =
      cond do
        gross_loss == 0.0 and gross_profit > 0.0 -> 99.99
        gross_loss == 0.0 -> 0.0
        true -> Float.round(gross_profit / gross_loss, 2)
      end

    max_dd =
      if length(losses) > 0,
        do: Float.round(Enum.min(losses), 2),
        else: 0.0

    %{
      total_trades: total_trades,
      win_rate_pct: win_rate,
      total_return_pct: total_return,
      profit_factor: profit_factor,
      max_drawdown_pct: abs(max_dd)
    }
  end

  def run_backtest(_, _, _) do
    %{
      total_trades: 0,
      win_rate_pct: 0.0,
      total_return_pct: 0.0,
      profit_factor: 0.0,
      max_drawdown_pct: 0.0
    }
  end
end
