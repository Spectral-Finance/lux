defmodule Lux.Integrations.TradingView.Analysis do
  @moduledoc """
  TradingView-style technical analysis helpers.

  The module is data-source agnostic: adapters can fetch chart data from
  TradingView-compatible feeds, REST polling, or WebSockets, then pass OHLCV
  bars here for deterministic indicators, alerts, signals, multi-timeframe
  summaries, and simple strategy backtests.
  """

  @doc """
  Normalizes OHLCV chart bars.
  """
  @spec normalize_bars([map()]) :: [map()]
  def normalize_bars(bars) when is_list(bars) do
    bars
    |> Enum.map(&normalize_bar/1)
    |> Enum.sort_by(& &1.time)
  end

  @doc """
  Calculates a simple moving average from close prices.
  """
  @spec sma([map()], pos_integer()) :: [map()]
  def sma(bars, period) when period > 0 do
    bars
    |> normalize_bars()
    |> rolling(period, fn window -> average(Enum.map(window, & &1.close)) end)
    |> Enum.map(fn {bar, value} -> indicator_point(bar, :sma, value, %{period: period}) end)
  end

  @doc """
  Calculates an exponential moving average from close prices.
  """
  @spec ema([map()], pos_integer()) :: [map()]
  def ema(bars, period) when period > 0 do
    multiplier = 2 / (period + 1)

    bars
    |> normalize_bars()
    |> Enum.reduce([], fn bar, acc ->
      value =
        case acc do
          [] -> bar.close
          [%{value: previous} | _] -> (bar.close - previous) * multiplier + previous
        end

      [indicator_point(bar, :ema, round_float(value), %{period: period}) | acc]
    end)
    |> Enum.reverse()
  end

  @doc """
  Calculates RSI using average gains and losses over a period.
  """
  @spec rsi([map()], pos_integer()) :: [map()]
  def rsi(bars, period \\ 14) when period > 0 do
    normalized = normalize_bars(bars)

    normalized
    |> Enum.chunk_every(period + 1, 1, :discard)
    |> Enum.map(fn window ->
      [first | rest] = window

      {gains, losses, _last_close} =
        Enum.reduce(rest, {0.0, 0.0, first.close}, fn bar, {gains, losses, previous_close} ->
          change = bar.close - previous_close
          {gains + max(change, 0), losses + abs(min(change, 0)), bar.close}
        end)

      avg_gain = gains / period
      avg_loss = losses / period
      value = if avg_loss == 0, do: 100.0, else: 100 - 100 / (1 + avg_gain / avg_loss)

      indicator_point(List.last(window), :rsi, round_float(value), %{period: period})
    end)
  end

  @doc """
  Calculates MACD from fast EMA, slow EMA, and signal EMA.
  """
  @spec macd([map()], map()) :: [map()]
  def macd(bars, opts \\ %{}) do
    fast = value(opts, :fast) || 12
    slow = value(opts, :slow) || 26
    signal_period = value(opts, :signal) || 9
    normalized = normalize_bars(bars)
    fast_values = ema(normalized, fast)
    slow_values = ema(normalized, slow)

    macd_line =
      Enum.zip(fast_values, slow_values)
      |> Enum.map(fn {fast_point, slow_point} ->
        indicator_point(fast_point, :macd, round_float(fast_point.value - slow_point.value), %{
          fast: fast,
          slow: slow
        })
      end)

    signal_values =
      macd_line
      |> Enum.map(fn point ->
        %{
          time: point.time,
          open: point.value,
          high: point.value,
          low: point.value,
          close: point.value,
          volume: 0.0
        }
      end)
      |> ema(signal_period)

    Enum.zip(macd_line, signal_values)
    |> Enum.map(fn {macd_point, signal_point} ->
      Map.merge(macd_point, %{
        signal: signal_point.value,
        histogram: round_float(macd_point.value - signal_point.value),
        params: %{fast: fast, slow: slow, signal: signal_period}
      })
    end)
  end

  @doc """
  Calculates Bollinger Bands from close prices.
  """
  @spec bollinger_bands([map()], map()) :: [map()]
  def bollinger_bands(bars, opts \\ %{}) do
    period = value(opts, :period) || 20
    multiplier = number(value(opts, :multiplier) || 2)

    bars
    |> normalize_bars()
    |> rolling(period, fn window ->
      closes = Enum.map(window, & &1.close)
      mean = average(closes)
      deviation = stddev(closes, mean)

      %{
        middle: round_float(mean),
        upper: round_float(mean + multiplier * deviation),
        lower: round_float(mean - multiplier * deviation)
      }
    end)
    |> Enum.map(fn {bar, bands} ->
      point = indicator_point(bar, :bollinger, bands.middle, %{period: period, multiplier: multiplier})

      Map.merge(point, bands)
    end)
  end

  @doc """
  Generates indicator-based trading signals.
  """
  @spec generate_signals([map()], map()) :: map()
  def generate_signals(bars, opts \\ %{}) do
    normalized = normalize_bars(bars)
    short = value(opts, :short_sma) || 3
    long = value(opts, :long_sma) || 5
    rsi_period = value(opts, :rsi_period) || 3
    short_sma = latest_value(sma(normalized, short))
    long_sma = latest_value(sma(normalized, long))
    latest_rsi = latest_value(rsi(normalized, rsi_period))
    latest = List.last(normalized)

    direction =
      cond do
        short_sma > long_sma and latest_rsi < 70 -> :bullish
        short_sma < long_sma and latest_rsi > 30 -> :bearish
        true -> :neutral
      end

    %{
      symbol: value(opts, :symbol),
      latest_close: if(latest, do: latest.close, else: 0.0),
      short_sma: short_sma,
      long_sma: long_sma,
      rsi: latest_rsi,
      direction: direction,
      confidence: confidence(short_sma, long_sma, latest_rsi)
    }
  end

  @doc """
  Evaluates alert rules against the latest bar and indicator values.
  """
  @spec evaluate_alerts([map()], [map()], map()) :: [map()]
  def evaluate_alerts(bars, rules, indicators \\ %{}) when is_list(rules) do
    latest = bars |> normalize_bars() |> List.last()

    Enum.filter(rules, fn rule ->
      alert_triggered?(latest, rule, indicators)
    end)
    |> Enum.map(&Map.put(&1, :triggered_at, if(latest, do: latest.time, else: nil)))
  end

  @doc """
  Summarizes several timeframes with the same signal engine.
  """
  @spec multi_timeframe_summary(map(), map()) :: map()
  def multi_timeframe_summary(timeframes, opts \\ %{}) when is_map(timeframes) do
    summaries =
      Map.new(timeframes, fn {timeframe, bars} ->
        {timeframe, generate_signals(bars, opts)}
      end)

    directions = summaries |> Map.values() |> Enum.map(& &1.direction)

    %{
      timeframes: summaries,
      consensus: consensus(directions),
      bullish_count: Enum.count(directions, &(&1 == :bullish)),
      bearish_count: Enum.count(directions, &(&1 == :bearish))
    }
  end

  @doc """
  Runs a simple moving-average crossover backtest.
  """
  @spec backtest_crossover([map()], map()) :: map()
  def backtest_crossover(bars, opts \\ %{}) do
    normalized = normalize_bars(bars)
    short = value(opts, :short) || 3
    long = value(opts, :long) || 5
    fee_bps = number(value(opts, :fee_bps) || 0)
    short_points = sma(normalized, short)
    long_points = sma(normalized, long)
    short_by_time = Map.new(short_points, &{&1.time, &1})

    points =
      long_points
      |> Enum.filter(&Map.has_key?(short_by_time, &1.time))
      |> Enum.map(fn long_point ->
        short_point = Map.fetch!(short_by_time, long_point.time)
        %{time: long_point.time, close: long_point.close, short: short_point.value, long: long_point.value}
      end)

    trades = crossover_trades(points, fee_bps)

    %{
      strategy: :sma_crossover,
      short: short,
      long: long,
      trade_count: length(trades),
      total_return: trades |> Enum.map(& &1.return) |> Enum.sum() |> round_float(),
      trades: trades
    }
  end

  defp crossover_trades(points, fee_bps) do
    {_state, trades} =
      Enum.reduce(points, {%{position: nil, previous: nil}, []}, fn point, {state, trades} ->
        signal = crossover_signal(state.previous, point)

        cond do
          signal == :buy and is_nil(state.position) ->
            {%{position: point, previous: point}, trades}

          signal == :sell and not is_nil(state.position) ->
            trade_return = (point.close - state.position.close) / state.position.close - fee_bps / 10_000

            trade = %{
              entry_time: state.position.time,
              exit_time: point.time,
              entry_price: state.position.close,
              exit_price: point.close,
              return: round_float(trade_return)
            }

            {%{position: nil, previous: point}, [trade | trades]}

          true ->
            {%{state | previous: point}, trades}
        end
      end)

    Enum.reverse(trades)
  end

  defp crossover_signal(nil, _point), do: :hold

  defp crossover_signal(previous, point) do
    cond do
      previous.short <= previous.long and point.short > point.long -> :buy
      previous.short >= previous.long and point.short < point.long -> :sell
      true -> :hold
    end
  end

  defp alert_triggered?(nil, _rule, _indicators), do: false

  defp alert_triggered?(bar, rule, indicators) do
    source = value(rule, :source) || :close
    operator = value(rule, :operator) || :gt
    threshold = number(value(rule, :threshold))
    current = alert_source_value(bar, source, indicators)

    case operator do
      :gt -> current > threshold
      "gt" -> current > threshold
      :gte -> current >= threshold
      "gte" -> current >= threshold
      :lt -> current < threshold
      "lt" -> current < threshold
      :lte -> current <= threshold
      "lte" -> current <= threshold
      :crosses_above -> current > threshold and number(value(rule, :previous)) <= threshold
      "crosses_above" -> current > threshold and number(value(rule, :previous)) <= threshold
      _ -> false
    end
  end

  defp alert_source_value(bar, :close, _indicators), do: bar.close
  defp alert_source_value(bar, "close", _indicators), do: bar.close
  defp alert_source_value(_bar, source, indicators), do: number(value(indicators, source))

  defp confidence(short_sma, long_sma, rsi) do
    spread = abs(short_sma - long_sma) / max(long_sma, 1)
    rsi_balance = abs(rsi - 50) / 50
    min(round_float(spread + rsi_balance), 1.0)
  end

  defp consensus(directions) do
    bullish = Enum.count(directions, &(&1 == :bullish))
    bearish = Enum.count(directions, &(&1 == :bearish))

    cond do
      bullish > bearish -> :bullish
      bearish > bullish -> :bearish
      true -> :neutral
    end
  end

  defp rolling(bars, period, fun) do
    bars
    |> Enum.chunk_every(period, 1, :discard)
    |> Enum.map(fn window ->
      {List.last(window), fun.(window)}
    end)
  end

  defp indicator_point(bar, name, value, params) do
    %{
      name: name,
      time: bar.time,
      close: bar.close,
      value: round_float(value),
      params: params
    }
  end

  defp latest_value([]), do: 0.0
  defp latest_value(points), do: points |> List.last() |> Map.get(:value, 0.0)

  defp normalize_bar(attrs) when is_map(attrs) do
    %{
      time: string(value(attrs, :time) || value(attrs, :timestamp)),
      open: number(value(attrs, :open) || value(attrs, :o)),
      high: number(value(attrs, :high) || value(attrs, :h)),
      low: number(value(attrs, :low) || value(attrs, :l)),
      close: number(value(attrs, :close) || value(attrs, :c)),
      volume: number(value(attrs, :volume) || value(attrs, :v))
    }
  end

  defp average([]), do: 0.0

  defp average(values) do
    values
    |> Enum.sum()
    |> Kernel./(max(length(values), 1))
    |> round_float()
  end

  defp stddev([], _mean), do: 0.0

  defp stddev(values, mean) do
    variance =
      values
      |> Enum.map(&((&1 - mean) * (&1 - mean)))
      |> average()

    :math.sqrt(variance)
  end

  defp value(map, key) when is_map(map), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))
  defp value(_map, _key), do: nil

  defp string(nil), do: ""
  defp string(value) when is_binary(value), do: value
  defp string(value) when is_atom(value), do: Atom.to_string(value)
  defp string(value), do: to_string(value)

  defp number(nil), do: 0.0
  defp number(value) when is_integer(value), do: value * 1.0
  defp number(value) when is_float(value), do: value

  defp number(value) when is_binary(value) do
    case Float.parse(value) do
      {number, _rest} -> number
      :error -> 0.0
    end
  end

  defp number(_value), do: 0.0

  defp round_float(value), do: Float.round(number(value), 6)
end
