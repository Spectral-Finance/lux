defmodule Lux.Prisms.TechnicalAnalysis.StrategyBacktest do
  @moduledoc """
  A prism that backtests a simple trading strategy against historical price data.

  Supports SMA crossover strategies and RSI-based strategies. Returns profit/loss,
  win rate, and trade details.

  ## Examples

      iex> Lux.Prisms.TechnicalAnalysis.StrategyBacktest.run(%{
      ...>   prices: [40, 41, 42, 41.5, 43, 44, 43.5, 45, 46, 47, 46.5, 48, 49, 50, 49.5, 51],
      ...>   strategy: "sma_crossover",
      ...>   fast_period: 3,
      ...>   slow_period: 5
      ...> })
      {:ok, %{total_return: number(), num_trades: integer(), trades: [...]}}
  """

  use Lux.Prism,
    name: "Strategy Backtest",
    description: "Backtests trading strategies against historical data",
    input_schema: %{
      type: :object,
      properties: %{
        prices: %{
          type: :array,
          description: "Array of closing prices for backtesting",
          items: %{type: :number}
        },
        strategy: %{
          type: :string,
          description: "Strategy to backtest",
          enum: ["sma_crossover", "rsi"],
          default: "sma_crossover"
        },
        fast_period: %{
          type: :integer,
          description: "Fast SMA period for crossover (default 5)",
          default: 5
        },
        slow_period: %{
          type: :integer,
          description: "Slow SMA period for crossover (default 20)",
          default: 20
        },
        rsi_period: %{
          type: :integer,
          description: "RSI period for RSI strategy (default 14)",
          default: 14
        },
        initial_capital: %{
          type: :number,
          description: "Starting capital (default 10000)",
          default: 10000
        }
      },
      required: ["prices"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        strategy: %{type: :string},
        initial_capital: %{type: :number},
        final_capital: %{type: :number},
        total_return_pct: %{type: :number},
        num_trades: %{type: :integer},
        win_rate: %{type: :number},
        max_drawdown_pct: %{type: :number},
        trades: %{type: :array, description: "List of individual trades"}
      },
      required: ["strategy", "initial_capital", "final_capital", "total_return_pct", "num_trades", "win_rate", "max_drawdown_pct", "trades"]
    }

  def handler(%{prices: prices} = input, _ctx) when is_list(prices) and length(prices) >= 10 do
    strategy = Map.get(input, :strategy, "sma_crossover")
    initial_capital = Map.get(input, :initial_capital, 10000)

    {trades, signals} = generate_signals(prices, input, strategy)

    {final_capital, win_count, total_trades, peak_capital, max_dd} =
      execute_trades(initial_capital, trades, prices)

    win_rate = if total_trades > 0, do: win_count / total_trades * 100, else: 0
    total_return = (final_capital - initial_capital) / initial_capital * 100

    {:ok, %{
      strategy: strategy,
      initial_capital: initial_capital,
      final_capital: Float.round(final_capital, 2),
      total_return_pct: Float.round(total_return, 2),
      num_trades: total_trades,
      win_rate: Float.round(win_rate, 2),
      max_drawdown_pct: Float.round(max_dd, 2),
      trades: Enum.map(trades, &truncate_trade/1)
    }}
  end

  def handler(%{prices: prices}, _ctx) when is_list(prices) do
    {:error, "prices must have at least 10 values for backtesting"}
  end

  def handler(input, _ctx) do
    {:error, "invalid input: #{inspect(input)}"}
  end

  defp generate_signals(prices, input, "sma_crossover") do
    fast_period = Map.get(input, :fast_period, 5)
    slow_period = Map.get(input, :slow_period, 20)

    fast_smas = sliding_sma(prices, fast_period)
    slow_smas = sliding_sma(prices, slow_period)

    min_len = min(length(fast_smas), length(slow_smas))
    fast = Enum.take(fast_smas, min_len)
    slow = Enum.take(slow_smas, min_len)

    Enum.zip(fast, slow)
    |> Enum.with_index()
    |> Enum.map(fn {{f, s}, idx} ->
      case {f > s, idx > 0} do
        {true, true} ->
          prev = Enum.at(Enum.zip(fast, slow), idx - 1)
          cond do
            elem(prev, 0) <= elem(prev, 1) -> {"buy", idx}
            true -> {"hold", idx}
          end
        {false, true} ->
          prev = Enum.at(Enum.zip(fast, slow), idx - 1)
          cond do
            elem(prev, 0) >= elem(prev, 1) -> {"sell", idx}
            true -> {"hold", idx}
          end
        _ -> {"hold", idx}
      end
    end)
  end

  defp generate_signals(prices, input, "rsi") do
    rsi_period = Map.get(input, :rsi_period, 14)
    rsi_series = calculate_rsi_simple(prices, rsi_period)

    Enum.zip(rsi_series, prices)
    |> Enum.with_index()
    |> Enum.map(fn {{rsi, _price}, idx} ->
      cond do
        rsi < 30 and idx > rsi_period -> {"buy", idx}
        rsi > 70 and idx > rsi_period -> {"sell", idx}
        true -> {"hold", idx}
      end
    end)
  end

  defp sliding_sma(prices, period) do
    Enum.chunk_every(prices, period, 1, :discard)
    |> Enum.map(&Enum.mean/1)
  end

  defp calculate_rsi_simple(prices, period) do
    if length(prices) <= period do
      [50.0]
    else
      changes = Enum.zip(Enum.drop(prices, -1), prices) |> Enum.map(fn {a, b} -> b - a end)
      avg_gain = Enum.take(changes, period) |> Enum.map(fn c -> if c > 0, do: c, else: 0 end) |> Enum.sum() |> Kernel./(period)
      avg_loss = Enum.take(changes, period) |> Enum.map(fn c -> if c < 0, do: abs(c), else: 0 end) |> Enum.sum() |> Kernel./(period)
      rs = if avg_loss == 0, do: 0, else: avg_gain / avg_loss
      rsi = 100 - (100 / (1 + rs))
      [rsi | Enum.drop(changes, period) |> Enum.reduce([{rsi, avg_gain, avg_loss}], fn c, [{prev_rsi, ag, al}] ->
        gain = if c > 0, do: c, else: 0
        loss = if c < 0, do: abs(c), else: 0
        nag = (ag * (period - 1) + gain) / period
        nal = (al * (period - 1) + loss) / period
        nrs = if nal == 0, do: 0, else: nag / nal
        [100 - (100 / (1 + nrs)), nag, nal]
      end) |> Enum.map(fn [r, _, _] -> r end)]
    end
  end

  defp execute_trades(initial_capital, trades, prices) do
    {result, _} =
      Enum.reduce(trades, {
        %{capital: initial_capital, position: 0, entry_price: 0, win_count: 0, total: 0, peak: initial_capital, max_dd: 0},
        []
      }, fn
        {"buy", idx}, {%{capital: cap, position: 0} = state, _} ->
          buy_price = Enum.at(prices, idx, List.last(prices))
          shares = floor(cap / buy_price)
          cost = shares * buy_price
          {%{state | capital: cap - cost, position: shares, entry_price: buy_price}, []}

        {"buy", _idx}, state ->
          {state, []}

        {"sell", idx}, {%{capital: cap, position: pos, entry_price: entry} = state, trades_acc} when pos > 0 do
          sell_price = Enum.at(prices, idx, List.last(prices))
          revenue = pos * sell_price
          pnl = (sell_price - entry) * pos
          new_cap = cap + revenue
          peak = max(new_cap, state.peak)
          dd = if peak > 0, do: (peak - new_cap) / peak * 100, else: 0
          max_dd = max(state.max_dd, dd)
          wc = if pnl > 0, do: state.win_count + 1, else: state.win_count
          {%{state | capital: new_cap, position: 0, entry_price: 0, win_count: wc, total: state.total + 1, peak: peak, max_dd: max_dd}, [
            %{type: "sell", entry_price: entry, exit_price: sell_price, pnl: Float.round(pnl, 2)} | trades_acc
          ]}

        {"sell", _idx}, state ->
          {state, []}

        _, state ->
          {state, []}
      end)

    final_capital = result.capital + result.position * List.last(prices)
    {final_capital, result.win_count, result.total, result.peak, result.max_dd}
  end

  defp truncate_trade(trade) do
    Map.take(trade, [:type, :entry_price, :exit_price, :pnl])
  end
end
