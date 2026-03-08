defmodule Lux.Prisms.TradingView.Backtester do
  @moduledoc """
  Strategy backtesting engine for TradingView-style technical analysis.

  Runs a trading strategy against historical price data and returns
  performance metrics including P&L, win rate, max drawdown, and
  Sharpe ratio.

  ## Usage

      result = Lux.Prisms.TradingView.Backtester.run(%{
        candles: candles,       # list of %{open:, high:, low:, close:, volume:, timestamp:}
        strategy: :sma_cross,   # built-in strategy or custom function
        params: %{fast: 10, slow: 20},
        initial_capital: 10_000.0,
        commission: 0.001       # 0.1% per trade
      })
  """

  use Lux.Prism,
    name: "TradingView Backtester",
    description: "Backtest trading strategies against historical price data",
    input_schema: %{
      type: :object,
      properties: %{
        candles: %{type: :array, description: "Historical OHLCV data"},
        strategy: %{type: :string, enum: ["sma_cross", "rsi_reversal", "macd_signal", "bollinger_bounce"]},
        params: %{type: :object, description: "Strategy parameters"},
        initial_capital: %{type: :number, description: "Starting capital"},
        commission: %{type: :number, description: "Commission rate per trade (e.g., 0.001 for 0.1%)"}
      },
      required: ["candles", "strategy"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        total_return: %{type: :number},
        win_rate: %{type: :number},
        total_trades: %{type: :integer},
        max_drawdown: %{type: :number},
        sharpe_ratio: %{type: :number},
        trades: %{type: :array}
      }
    }

  @impl true
  def handler(params, _opts) do
    candles = params[:candles] || params["candles"] || []
    strategy = to_strategy(params[:strategy] || params["strategy"] || "sma_cross")
    strategy_params = params[:params] || params["params"] || %{}
    initial_capital = params[:initial_capital] || params["initial_capital"] || 10_000.0
    commission = params[:commission] || params["commission"] || 0.001

    if length(candles) < 2 do
      {:error, "Need at least 2 candles for backtesting"}
    else
      result = run_backtest(candles, strategy, strategy_params, initial_capital, commission)
      {:ok, result}
    end
  end

  @doc "Run a backtest with the given parameters (direct call)."
  def run(params), do: handler(params, [])

  # Strategy implementations

  defp to_strategy("sma_cross"), do: :sma_cross
  defp to_strategy("rsi_reversal"), do: :rsi_reversal
  defp to_strategy("macd_signal"), do: :macd_signal
  defp to_strategy("bollinger_bounce"), do: :bollinger_bounce
  defp to_strategy(s) when is_atom(s), do: s
  defp to_strategy(_), do: :sma_cross

  defp run_backtest(candles, strategy, params, initial_capital, commission) do
    closes = Enum.map(candles, fn c -> to_float(c[:close] || c["close"]) end)
    signals = generate_signals(strategy, candles, closes, params)

    {trades, final_capital} =
      execute_signals(signals, closes, initial_capital, commission)

    metrics = calculate_metrics(trades, initial_capital, final_capital, closes)

    Map.merge(metrics, %{
      trades: Enum.take(trades, -50),
      strategy: Atom.to_string(strategy),
      candle_count: length(candles),
      final_capital: Float.round(final_capital, 2)
    })
  end

  defp generate_signals(:sma_cross, _candles, closes, params) do
    fast = params[:fast] || params["fast"] || 10
    slow = params[:slow] || params["slow"] || 20

    fast_sma = sma(closes, fast)
    slow_sma = sma(closes, slow)

    Enum.zip(fast_sma, slow_sma)
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.with_index(max(fast, slow))
    |> Enum.map(fn {[{prev_fast, prev_slow}, {curr_fast, curr_slow}], idx} ->
      cond do
        prev_fast <= prev_slow and curr_fast > curr_slow -> {idx, :buy}
        prev_fast >= prev_slow and curr_fast < curr_slow -> {idx, :sell}
        true -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp generate_signals(:rsi_reversal, _candles, closes, params) do
    period = params[:period] || params["period"] || 14
    oversold = params[:oversold] || params["oversold"] || 30
    overbought = params[:overbought] || params["overbought"] || 70

    rsi_values = rsi(closes, period)

    rsi_values
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.with_index(period + 1)
    |> Enum.map(fn {[prev, curr], idx} ->
      cond do
        prev < oversold and curr >= oversold -> {idx, :buy}
        prev > overbought and curr <= overbought -> {idx, :sell}
        true -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp generate_signals(:macd_signal, _candles, closes, params) do
    fast = params[:fast] || params["fast"] || 12
    slow = params[:slow] || params["slow"] || 26
    signal_period = params[:signal] || params["signal"] || 9

    {macd_line, signal_line} = macd(closes, fast, slow, signal_period)

    Enum.zip(macd_line, signal_line)
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.with_index(slow + signal_period)
    |> Enum.map(fn {[{prev_m, prev_s}, {curr_m, curr_s}], idx} ->
      cond do
        prev_m <= prev_s and curr_m > curr_s -> {idx, :buy}
        prev_m >= prev_s and curr_m < curr_s -> {idx, :sell}
        true -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp generate_signals(:bollinger_bounce, _candles, closes, params) do
    period = params[:period] || params["period"] || 20
    std_dev = params[:std_dev] || params["std_dev"] || 2.0

    bands = bollinger_bands(closes, period, std_dev)

    bands
    |> Enum.with_index(period)
    |> Enum.map(fn {{lower, _mid, upper}, idx} ->
      price = Enum.at(closes, idx)

      cond do
        price <= lower -> {idx, :buy}
        price >= upper -> {idx, :sell}
        true -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp generate_signals(_, _, _, _), do: []

  # Trade execution

  defp execute_signals(signals, closes, initial_capital, commission) do
    {trades, capital, position} =
      Enum.reduce(signals, {[], initial_capital, nil}, fn
        {idx, :buy}, {trades, capital, nil} ->
          price = Enum.at(closes, idx, 0.0)
          if price == 0.0 do
            {trades, capital, nil}
          else
            cost = capital * commission
            shares = (capital - cost) / price
            {trades, 0.0, %{entry_idx: idx, entry_price: price, shares: shares, cost: cost}}
          end

        {idx, :sell}, {trades, _capital, %{} = pos} ->
          price = Enum.at(closes, idx, 0.0)
          if price == 0.0 do
            {trades, pos.shares * pos.entry_price, nil}
          else
          proceeds = pos.shares * price
          cost = proceeds * commission
          net = proceeds - cost
          pnl = net - pos.shares * pos.entry_price

          trade = %{
            entry_idx: pos.entry_idx,
            exit_idx: idx,
            entry_price: Float.round(pos.entry_price, 4),
            exit_price: Float.round(price, 4),
            pnl: Float.round(pnl, 4),
            return_pct: Float.round(pnl / (pos.shares * pos.entry_price) * 100, 2),
            commission: Float.round(pos.cost + cost, 4)
          }

          {[trade | trades], net, nil}
          end

        _, acc ->
          acc
      end)

    # If still in position, calculate unrealized
    final_capital =
      case position do
        nil -> capital
        pos -> pos.shares * List.last(closes)
      end

    {Enum.reverse(trades), final_capital}
  end

  # Metrics

  defp calculate_metrics(trades, initial_capital, final_capital, _closes) do
    total_return = (final_capital - initial_capital) / initial_capital * 100
    wins = Enum.count(trades, &(&1.pnl > 0))
    total = length(trades)
    win_rate = if total > 0, do: wins / total * 100, else: 0.0

    returns = Enum.map(trades, & &1.return_pct)

    max_drawdown = calculate_max_drawdown(trades, initial_capital)

    sharpe =
      if length(returns) > 1 do
        avg = Enum.sum(returns) / length(returns)
        variance = Enum.sum(Enum.map(returns, fn r -> (r - avg) * (r - avg) end)) / (length(returns) - 1)
        std = :math.sqrt(max(variance, 0.0001))
        Float.round(avg / std * :math.sqrt(252), 2)
      else
        0.0
      end

    %{
      total_return: Float.round(total_return, 2),
      win_rate: Float.round(win_rate, 2),
      total_trades: total,
      winning_trades: wins,
      losing_trades: total - wins,
      max_drawdown: Float.round(max_drawdown, 2),
      sharpe_ratio: sharpe,
      avg_trade_return: if(total > 0, do: Float.round(Enum.sum(returns) / total, 2), else: 0.0)
    }
  end

  defp calculate_max_drawdown(trades, initial_capital) do
    {_, max_dd} =
      Enum.reduce(trades, {initial_capital, 0.0}, fn trade, {peak, max_dd} ->
        equity = peak + trade.pnl
        new_peak = max(peak, equity)
        dd = (new_peak - equity) / new_peak * 100
        {new_peak, max(max_dd, dd)}
      end)

    max_dd
  end

  # Technical indicators

  defp sma(values, period) do
    values
    |> Enum.chunk_every(period, 1, :discard)
    |> Enum.map(fn window -> Enum.sum(window) / period end)
  end

  defp ema(values, period) do
    k = 2.0 / (period + 1)
    [first | rest] = Enum.take(values, period)
    initial = Enum.sum([first | Enum.take(rest, period - 1)]) / period

    rest
    |> Enum.drop(period - 2)
    |> Enum.scan(initial, fn val, prev -> val * k + prev * (1 - k) end)
  end

  defp rsi(closes, period) do
    changes =
      closes
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [prev, curr] -> curr - prev end)

    gains = Enum.map(changes, &max(&1, 0.0))
    losses = Enum.map(changes, &abs(min(&1, 0.0)))

    avg_gains = sma(gains, period)
    avg_losses = sma(losses, period)

    Enum.zip(avg_gains, avg_losses)
    |> Enum.map(fn
      {_, 0.0} -> 100.0
      {gain, loss} -> 100.0 - 100.0 / (1.0 + gain / loss)
    end)
  end

  defp macd(closes, fast, slow, signal_period) do
    fast_ema = ema(closes, fast)
    slow_ema = ema(closes, slow)

    # Align lengths
    diff = length(fast_ema) - length(slow_ema)
    fast_trimmed = Enum.drop(fast_ema, max(diff, 0))
    slow_trimmed = Enum.drop(slow_ema, max(-diff, 0))

    macd_line = Enum.zip(fast_trimmed, slow_trimmed) |> Enum.map(fn {f, s} -> f - s end)
    signal_line = sma(macd_line, signal_period)

    # Align
    macd_trimmed = Enum.drop(macd_line, length(macd_line) - length(signal_line))

    {macd_trimmed, signal_line}
  end

  defp bollinger_bands(closes, period, std_dev_mult) do
    closes
    |> Enum.chunk_every(period, 1, :discard)
    |> Enum.map(fn window ->
      mid = Enum.sum(window) / period
      variance = Enum.sum(Enum.map(window, fn v -> (v - mid) * (v - mid) end)) / period
      std = :math.sqrt(variance)
      {mid - std_dev_mult * std, mid, mid + std_dev_mult * std}
    end)
  end

  defp to_float(v) when is_float(v), do: v
  defp to_float(v) when is_integer(v), do: v * 1.0
  defp to_float(v) when is_binary(v), do: String.to_float(v)
  defp to_float(_), do: 0.0
end
