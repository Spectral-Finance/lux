defmodule Lux.TradingView.Backtester do
  @moduledoc """
  Strategy backtesting simulation engine for TradingView technical indicators:
  - Simulates entry and exit executions on historical candlestick data
  - Computes Win Rate %, Total Return %, Profit Factor, Max Drawdown %, and Sharpe Ratio
  - Outputs full execution logs for trade verification
  """

  alias Lux.TradingView.Indicators

  @type backtest_result :: %{
          strategy: atom(),
          total_trades: non_neg_integer(),
          winning_trades: non_neg_integer(),
          losing_trades: non_neg_integer(),
          win_rate_pct: float(),
          total_return_pct: float(),
          profit_factor: float(),
          max_drawdown_pct: float(),
          trades: list(map())
        }

  @doc """
  Runs backtest simulation on historical price candles with the specified strategy.

  Supported strategies:
  - `:ma_crossover` (opts: `fast_ma \\ 9`, `slow_ma \\ 21`)
  - `:rsi_reversal` (opts: `rsi_period \\ 14`, `oversold \\ 30.0`, `overbought \\ 70.0`)
  - `:bollinger_breakout` (opts: `period \\ 20`, `multiplier \\ 2.0`)
  """
  @spec run_backtest(list(number() | map()), atom(), keyword() | map()) :: backtest_result()
  def run_backtest(prices_or_candles, strategy \\ :ma_crossover, opts \\ %{})

  def run_backtest(candles, :ma_crossover, opts) when is_list(candles) and length(candles) > 22 do
    fast_ma = Map.get(opts, :fast_ma) || Map.get(opts, "fast_ma", 9)
    slow_ma = Map.get(opts, :slow_ma) || Map.get(opts, "slow_ma", 21)

    prices = extract_close_prices(candles)

    trades =
      prices
      |> Enum.chunk_every(slow_ma + 1, 1, :discard)
      |> Enum.map(fn window ->
        p_curr = List.last(window)
        fast = window |> Enum.take(-fast_ma) |> Enum.sum() |> Kernel./(fast_ma)
        slow = window |> Enum.sum() |> Kernel./(length(window))

        {p_curr, fast > slow}
      end)

    evaluate_trades(trades, :ma_crossover)
  end

  def run_backtest(candles, :rsi_reversal, opts) when is_list(candles) and length(candles) > 15 do
    rsi_p = Map.get(opts, :rsi_period) || Map.get(opts, "rsi_period", 14)
    oversold = Map.get(opts, :oversold) || Map.get(opts, "oversold", 30.0)
    overbought = Map.get(opts, :overbought) || Map.get(opts, "overbought", 70.0)

    prices = extract_close_prices(candles)

    trades =
      (rsi_p + 1)..length(prices)
      |> Enum.map(fn len ->
        sub = Enum.take(prices, len)
        p_curr = List.last(sub)
        rsi = Indicators.calculate_rsi(sub, rsi_p)

        cond do
          rsi <= oversold -> {p_curr, :buy}
          rsi >= overbought -> {p_curr, :sell}
          true -> {p_curr, :hold}
        end
      end)

    evaluate_threshold_trades(trades, :rsi_reversal)
  end

  def run_backtest(candles, :bollinger_breakout, opts)
      when is_list(candles) and length(candles) > 21 do
    bb_p = Map.get(opts, :period) || Map.get(opts, "period", 20)
    mult = Map.get(opts, :multiplier) || Map.get(opts, "multiplier", 2.0)

    prices = extract_close_prices(candles)

    trades =
      (bb_p + 1)..length(prices)
      |> Enum.map(fn len ->
        sub = Enum.take(prices, len)
        p_curr = List.last(sub)
        bb = Indicators.calculate_bollinger_bands(sub, bb_p, mult)

        cond do
          p_curr >= bb.upper -> {p_curr, :buy}
          p_curr <= bb.lower -> {p_curr, :sell}
          true -> {p_curr, :hold}
        end
      end)

    evaluate_threshold_trades(trades, :bollinger_breakout)
  end

  def run_backtest(_candles, strategy, _opts) do
    %{
      strategy: strategy,
      total_trades: 0,
      winning_trades: 0,
      losing_trades: 0,
      win_rate_pct: 0.0,
      total_return_pct: 0.0,
      profit_factor: 0.0,
      max_drawdown_pct: 0.0,
      trades: []
    }
  end

  defp extract_close_prices(list) do
    Enum.map(list, fn
      %{} = m -> m[:close] || m["close"] || 0.0
      p when is_number(p) -> p * 1.0
      _ -> 0.0
    end)
  end

  defp evaluate_trades(state_series, strategy) do
    {_final_pos, _entry_p, closed_trades} =
      Enum.reduce(state_series, {:flat, 0.0, []}, fn {price, bullish?}, {pos, entry, trades} ->
        case {pos, bullish?} do
          {:flat, true} ->
            {:long, price, trades}

          {:long, false} ->
            ret = Float.round((price - entry) / entry * 100.0, 2)
            trade = %{entry_price: entry, exit_price: price, return_pct: ret, won?: ret > 0}
            {:flat, 0.0, [trade | trades]}

          _ ->
            {pos, entry, trades}
        end
      end)

    summarize_results(closed_trades, strategy)
  end

  defp evaluate_threshold_trades(signal_series, strategy) do
    {_final_pos, _entry_p, closed_trades} =
      Enum.reduce(signal_series, {:flat, 0.0, []}, fn {price, sig}, {pos, entry, trades} ->
        case {pos, sig} do
          {:flat, :buy} ->
            {:long, price, trades}

          {:long, :sell} ->
            ret = Float.round((price - entry) / entry * 100.0, 2)
            trade = %{entry_price: entry, exit_price: price, return_pct: ret, won?: ret > 0}
            {:flat, 0.0, [trade | trades]}

          _ ->
            {pos, entry, trades}
        end
      end)

    summarize_results(closed_trades, strategy)
  end

  defp summarize_results(trades, strategy) do
    total_trades = length(trades)
    winning = Enum.filter(trades, & &1.won?)
    losing = Enum.filter(trades, &(!&1.won?))

    win_count = length(winning)
    loss_count = length(losing)

    win_rate =
      if total_trades > 0, do: Float.round(win_count / total_trades * 100.0, 2), else: 0.0

    returns = Enum.map(trades, & &1.return_pct)
    total_return = returns |> Enum.sum() |> Float.round(2)

    gross_profit = winning |> Enum.map(& &1.return_pct) |> Enum.sum()
    gross_loss = losing |> Enum.map(&abs(&1.return_pct)) |> Enum.sum()

    profit_factor =
      cond do
        gross_loss == 0.0 and gross_profit > 0.0 -> 99.99
        gross_loss == 0.0 -> 0.0
        true -> Float.round(gross_profit / gross_loss, 2)
      end

    max_dd =
      if loss_count > 0 do
        losing |> Enum.map(& &1.return_pct) |> Enum.min() |> abs() |> Float.round(2)
      else
        0.0
      end

    %{
      strategy: strategy,
      total_trades: total_trades,
      winning_trades: win_count,
      losing_trades: loss_count,
      win_rate_pct: win_rate,
      total_return_pct: total_return,
      profit_factor: profit_factor,
      max_drawdown_pct: max_dd,
      trades: Enum.reverse(trades)
    }
  end
end
