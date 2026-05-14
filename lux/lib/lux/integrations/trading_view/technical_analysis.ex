defmodule Lux.Integrations.TradingView.TechnicalAnalysis do
  @moduledoc """
  Deterministic TradingView-style technical analysis helpers.

  The module keeps account-specific TradingView transport out of scope. It
  normalizes OHLCV bars, calculates common indicators, evaluates alert rules,
  summarizes multiple timeframes, and runs a simple crossover backtest so data
  adapters can plug in later without changing analysis behavior.
  """

  @default_indicators %{
    sma: [20],
    ema: [20],
    rsi: [14],
    macd: %{fast: 12, slow: 26, signal: 9},
    bollinger: %{period: 20, deviations: 2.0}
  }

  @known_fields %{
    "open" => :open,
    "high" => :high,
    "low" => :low,
    "close" => :close,
    "volume" => :volume,
    "rsi" => :rsi,
    "sma" => :sma,
    "ema" => :ema,
    "macd" => :macd,
    "macd_signal" => :macd_signal,
    "macd_histogram" => :macd_histogram
  }

  @doc """
  Runs full chart analysis: normalization, indicators, alerts, signals,
  backtest, and optional multi-timeframe summaries.
  """
  @spec analyze([map()], keyword() | map()) :: map()
  def analyze(bars, opts \\ %{}) do
    opts = normalize_options(opts)
    chart = normalize_chart(bars, opts)
    indicators = calculate_indicators(chart.bars, Map.get(opts, :indicators, @default_indicators))
    alerts = evaluate_alerts(chart.bars, indicators, Map.get(opts, :alerts, []))
    signals = generate_signals(chart.bars, indicators)
    backtest = backtest_strategy(chart.bars, Map.get(opts, :strategy, %{}))
    timeframes = multi_timeframe_summary(Map.get(opts, :timeframes, %{}))

    %{
      chart: chart,
      indicators: indicators,
      alerts: alerts,
      signals: signals,
      backtest: backtest,
      timeframes: timeframes,
      summary: %{
        bars: length(chart.bars),
        latest_close: chart.latest && chart.latest.close,
        trend: signals.trend,
        triggered_alerts: Enum.count(alerts, & &1.triggered),
        backtest_return_pct: backtest.return_pct
      }
    }
  end

  @doc """
  Normalizes OHLCV chart rows from atom-keyed or string-keyed maps.
  """
  @spec normalize_chart([map()], keyword() | map()) :: map()
  def normalize_chart(rows, opts \\ %{}) do
    opts = normalize_options(opts)

    bars =
      rows
      |> Enum.map(&normalize_bar/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(& &1.time)

    %{
      symbol: Map.get(opts, :symbol),
      timeframe: Map.get(opts, :timeframe),
      bars: bars,
      latest: List.last(bars),
      range: %{
        from: bars |> List.first() |> then(&(&1 && &1.time)),
        to: bars |> List.last() |> then(&(&1 && &1.time))
      }
    }
  end

  @doc """
  Calculates SMA, EMA, RSI, MACD, and Bollinger Band series.
  """
  @spec calculate_indicators([map()], keyword() | map()) :: map()
  def calculate_indicators(bars, config \\ @default_indicators) do
    config = normalize_indicator_config(config)
    closes = Enum.map(bars, & &1.close)

    %{
      sma: Map.new(config.sma, fn period -> {period, sma_series(bars, closes, period)} end),
      ema: Map.new(config.ema, fn period -> {period, ema_series(bars, closes, period)} end),
      rsi: Map.new(config.rsi, fn period -> {period, rsi_series(bars, closes, period)} end),
      macd: macd_series(bars, closes, config.macd),
      bollinger: bollinger_series(bars, closes, config.bollinger)
    }
  end

  @doc """
  Evaluates alert rules against the latest and previous chart state.
  """
  @spec evaluate_alerts([map()], map(), [map()]) :: [map()]
  def evaluate_alerts(bars, indicators, rules) do
    current = point_state(bars, indicators, -1)
    previous = point_state(bars, indicators, -2)

    Enum.map(rules, fn rule ->
      normalized = normalize_rule(rule)
      triggered = rule_triggered?(normalized, current, previous)

      %{
        id: normalized.id,
        field: normalized.field,
        operator: normalized.operator,
        threshold: normalized.value,
        current: Map.get(current, normalized.field),
        previous: Map.get(previous, normalized.field),
        triggered: triggered,
        severity: if(triggered, do: normalized.severity, else: :none)
      }
    end)
  end

  @doc """
  Generates a compact signal summary from the latest indicator state.
  """
  @spec generate_signals([map()], map()) :: map()
  def generate_signals(bars, indicators) do
    current = point_state(bars, indicators, -1)
    close = Map.get(current, :close)
    sma = Map.get(current, :sma)
    rsi = Map.get(current, :rsi)
    macd_histogram = Map.get(current, :macd_histogram)

    bullish =
      Enum.count(
        [
          present?(close) and present?(sma) and close > sma,
          present?(rsi) and rsi >= 50 and rsi < 70,
          present?(macd_histogram) and macd_histogram > 0
        ],
        & &1
      )

    bearish =
      Enum.count(
        [
          present?(close) and present?(sma) and close < sma,
          present?(rsi) and rsi < 50,
          present?(macd_histogram) and macd_histogram < 0
        ],
        & &1
      )

    trend =
      cond do
        bullish >= 2 -> :bullish
        bearish >= 2 -> :bearish
        true -> :neutral
      end

    %{
      trend: trend,
      score: bullish - bearish,
      reasons: signal_reasons(current),
      latest: current
    }
  end

  @doc """
  Backtests a simple moving-average crossover strategy.
  """
  @spec backtest_strategy([map()], keyword() | map()) :: map()
  def backtest_strategy(bars, strategy \\ %{}) do
    strategy = normalize_strategy(strategy)
    closes = Enum.map(bars, & &1.close)
    fast = keyed_values(sma_series(bars, closes, strategy.fast_period))
    slow = keyed_values(sma_series(bars, closes, strategy.slow_period))

    state =
      bars
      |> Enum.reduce(%{cash: strategy.initial_cash, position: 0.0, trades: []}, fn bar, acc ->
        fast_value = Map.get(fast, bar.time)
        slow_value = Map.get(slow, bar.time)

        cond do
          present?(fast_value) and present?(slow_value) and fast_value > slow_value and
              acc.position == 0.0 ->
            units = acc.cash / bar.close
            trade = %{side: :buy, time: bar.time, price: bar.close, units: units}
            %{acc | cash: 0.0, position: units, trades: [trade | acc.trades]}

          present?(fast_value) and present?(slow_value) and fast_value < slow_value and
              acc.position > 0.0 ->
            cash = acc.position * bar.close
            trade = %{side: :sell, time: bar.time, price: bar.close, units: acc.position}
            %{acc | cash: cash, position: 0.0, trades: [trade | acc.trades]}

          true ->
            acc
        end
      end)

    last_close = bars |> List.last() |> then(&(&1 && &1.close)) || 0.0
    final_equity = state.cash + state.position * last_close

    %{
      strategy: :sma_crossover,
      fast_period: strategy.fast_period,
      slow_period: strategy.slow_period,
      initial_cash: strategy.initial_cash,
      final_equity: round_float(final_equity),
      return_pct: pct_change(final_equity, strategy.initial_cash),
      open_position: round_float(state.position),
      trades: state.trades |> Enum.reverse() |> Enum.map(&round_trade/1),
      trade_count: length(state.trades)
    }
  end

  @doc """
  Summarizes multiple timeframe datasets.
  """
  @spec multi_timeframe_summary(map()) :: map()
  def multi_timeframe_summary(timeframes) when is_map(timeframes) do
    Map.new(timeframes, fn {timeframe, rows} ->
      chart = normalize_chart(rows, timeframe: timeframe)
      indicators = calculate_indicators(chart.bars, %{sma: [20], ema: [], rsi: [14]})
      signals = generate_signals(chart.bars, indicators)

      {timeframe,
       %{
         bars: length(chart.bars),
         latest_close: chart.latest && chart.latest.close,
         trend: signals.trend,
         score: signals.score
       }}
    end)
  end

  def multi_timeframe_summary(_timeframes), do: %{}

  defp normalize_bar(row) when is_map(row) do
    with {:ok, time} <- normalize_time(fetch_value(row, :time) || fetch_value(row, :timestamp)),
         {:ok, open} <- normalize_number(fetch_value(row, :open)),
         {:ok, high} <- normalize_number(fetch_value(row, :high)),
         {:ok, low} <- normalize_number(fetch_value(row, :low)),
         {:ok, close} <- normalize_number(fetch_value(row, :close)) do
      %{
        time: time,
        open: open,
        high: high,
        low: low,
        close: close,
        volume: normalize_number(fetch_value(row, :volume), 0.0)
      }
    else
      _ -> nil
    end
  end

  defp normalize_bar(_row), do: nil

  defp sma_series(bars, values, period) when period > 0 do
    values
    |> Enum.chunk_every(period, 1, :discard)
    |> Enum.with_index(period - 1)
    |> Enum.map(fn {window, index} ->
      %{time: Enum.at(bars, index).time, value: average(window)}
    end)
  end

  defp sma_series(_bars, _values, _period), do: []

  defp ema_series(bars, values, period) when period > 0 and length(values) > 0 do
    values
    |> ema_values(period)
    |> Enum.zip(bars)
    |> Enum.map(fn {value, bar} -> %{time: bar.time, value: round_float(value)} end)
  end

  defp ema_series(_bars, _values, _period), do: []

  defp rsi_series(bars, values, period) when period > 0 and length(values) > period do
    values
    |> deltas()
    |> Enum.chunk_every(period, 1, :discard)
    |> Enum.with_index(period)
    |> Enum.map(fn {window, index} ->
      gains = window |> Enum.filter(&(&1 > 0)) |> Enum.sum()
      losses = window |> Enum.filter(&(&1 < 0)) |> Enum.map(&abs/1) |> Enum.sum()

      rsi =
        cond do
          losses == 0.0 -> 100.0
          true -> 100.0 - 100.0 / (1.0 + gains / losses)
        end

      %{time: Enum.at(bars, index).time, value: round_float(rsi)}
    end)
  end

  defp rsi_series(_bars, _values, _period), do: []

  defp macd_series(bars, values, %{fast: fast, slow: slow, signal: signal}) do
    fast_values = ema_values(values, fast)
    slow_values = ema_values(values, slow)

    line =
      fast_values
      |> Enum.zip(slow_values)
      |> Enum.map(fn {fast_value, slow_value} -> fast_value - slow_value end)

    signal_values = ema_values(line, signal)

    line
    |> Enum.zip(signal_values)
    |> Enum.zip(bars)
    |> Enum.map(fn {{macd, signal_value}, bar} ->
      %{
        time: bar.time,
        macd: round_float(macd),
        signal: round_float(signal_value),
        histogram: round_float(macd - signal_value)
      }
    end)
  end

  defp macd_series(_bars, _values, _config), do: []

  defp bollinger_series(bars, values, %{period: period, deviations: deviations})
       when period > 0 do
    values
    |> Enum.chunk_every(period, 1, :discard)
    |> Enum.with_index(period - 1)
    |> Enum.map(fn {window, index} ->
      mid = average(window)
      stddev = stddev(window, mid)

      %{
        time: Enum.at(bars, index).time,
        middle: round_float(mid),
        upper: round_float(mid + deviations * stddev),
        lower: round_float(mid - deviations * stddev)
      }
    end)
  end

  defp bollinger_series(_bars, _values, _config), do: []

  defp point_state([], _indicators, _offset), do: %{}

  defp point_state(bars, indicators, offset) do
    bar = Enum.at(bars, offset) || %{}
    time = Map.get(bar, :time)

    %{
      time: time,
      open: Map.get(bar, :open),
      high: Map.get(bar, :high),
      low: Map.get(bar, :low),
      close: Map.get(bar, :close),
      volume: Map.get(bar, :volume),
      sma: latest_indicator_value(indicators.sma, time),
      ema: latest_indicator_value(indicators.ema, time),
      rsi: latest_indicator_value(indicators.rsi, time),
      macd: time_lookup(indicators.macd, time, :macd),
      macd_signal: time_lookup(indicators.macd, time, :signal),
      macd_histogram: time_lookup(indicators.macd, time, :histogram),
      bollinger: Enum.find(indicators.bollinger, &(&1.time == time))
    }
  end

  defp latest_indicator_value(group, time) when is_map(group) do
    group
    |> Map.values()
    |> Enum.flat_map(& &1)
    |> Enum.find_value(fn point -> if point.time == time, do: point.value end)
  end

  defp latest_indicator_value(_group, _time), do: nil

  defp time_lookup(points, time, key) do
    points
    |> Enum.find(&(&1.time == time))
    |> then(&(&1 && Map.get(&1, key)))
  end

  defp normalize_rule(rule) do
    %{
      id: fetch_value(rule, :id) || "alert",
      field: normalize_field(fetch_value(rule, :field) || :close),
      operator: normalize_operator(fetch_value(rule, :operator) || :above),
      value: normalize_number(fetch_value(rule, :value), 0.0),
      severity: normalize_severity(fetch_value(rule, :severity) || :info)
    }
  end

  defp rule_triggered?(%{operator: :above, field: field, value: value}, current, _previous),
    do: compare(Map.get(current, field), value, &>/2)

  defp rule_triggered?(%{operator: :below, field: field, value: value}, current, _previous),
    do: compare(Map.get(current, field), value, &</2)

  defp rule_triggered?(%{operator: :at_or_above, field: field, value: value}, current, _previous),
    do: compare(Map.get(current, field), value, &>=/2)

  defp rule_triggered?(%{operator: :at_or_below, field: field, value: value}, current, _previous),
    do: compare(Map.get(current, field), value, &<=/2)

  defp rule_triggered?(
         %{operator: :crosses_above, field: field, value: value},
         current,
         previous
       ),
       do:
         compare(Map.get(previous, field), value, &<=/2) and
           compare(Map.get(current, field), value, &>/2)

  defp rule_triggered?(
         %{operator: :crosses_below, field: field, value: value},
         current,
         previous
       ),
       do:
         compare(Map.get(previous, field), value, &>=/2) and
           compare(Map.get(current, field), value, &</2)

  defp rule_triggered?(_rule, _current, _previous), do: false

  defp compare(left, right, fun) when is_number(left) and is_number(right), do: fun.(left, right)
  defp compare(_left, _right, _fun), do: false

  defp signal_reasons(current) do
    [
      reason(
        Map.get(current, :close),
        Map.get(current, :sma),
        "close above SMA",
        "close below SMA"
      ),
      reason(Map.get(current, :rsi), 50.0, "RSI above 50", "RSI below 50"),
      reason(
        Map.get(current, :macd_histogram),
        0.0,
        "MACD histogram positive",
        "MACD histogram negative"
      )
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp reason(left, right, positive, negative) when is_number(left) and is_number(right) do
    cond do
      left > right -> positive
      left < right -> negative
      true -> nil
    end
  end

  defp reason(_left, _right, _positive, _negative), do: nil

  defp keyed_values(points), do: Map.new(points, fn point -> {point.time, point.value} end)

  defp ema_values([], _period), do: []

  defp ema_values([first | rest], period) do
    multiplier = 2.0 / (period + 1)

    rest
    |> Enum.reduce([first], fn value, [previous | _] = acc ->
      [value * multiplier + previous * (1 - multiplier) | acc]
    end)
    |> Enum.reverse()
  end

  defp deltas(values) do
    values
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [previous, current] -> current - previous end)
  end

  defp average(values), do: round_float(Enum.sum(values) / length(values))

  defp stddev(values, average) do
    variance =
      values
      |> Enum.map(fn value -> :math.pow(value - average, 2) end)
      |> Enum.sum()
      |> Kernel./(length(values))

    :math.sqrt(variance)
  end

  defp pct_change(_final, initial) when initial == 0.0, do: 0.0
  defp pct_change(final, initial), do: round_float((final - initial) / initial * 100.0)

  defp round_trade(trade),
    do: %{trade | price: round_float(trade.price), units: round_float(trade.units)}

  defp round_float(value) when is_float(value), do: Float.round(value, 6)
  defp round_float(value) when is_integer(value), do: value / 1
  defp round_float(_value), do: nil

  defp present?(value), do: is_number(value)

  defp normalize_indicator_config(config) do
    config = normalize_options(config)
    macd = Map.merge(@default_indicators.macd, normalize_options(Map.get(config, :macd, %{})))

    bollinger =
      Map.merge(
        @default_indicators.bollinger,
        normalize_options(Map.get(config, :bollinger, %{}))
      )

    %{
      sma:
        config
        |> Map.get(:sma, @default_indicators.sma)
        |> List.wrap()
        |> Enum.map(&normalize_integer(&1, 20)),
      ema:
        config
        |> Map.get(:ema, @default_indicators.ema)
        |> List.wrap()
        |> Enum.map(&normalize_integer(&1, 20)),
      rsi:
        config
        |> Map.get(:rsi, @default_indicators.rsi)
        |> List.wrap()
        |> Enum.map(&normalize_integer(&1, 14)),
      macd: %{
        fast: normalize_integer(Map.get(macd, :fast), @default_indicators.macd.fast),
        slow: normalize_integer(Map.get(macd, :slow), @default_indicators.macd.slow),
        signal: normalize_integer(Map.get(macd, :signal), @default_indicators.macd.signal)
      },
      bollinger: %{
        period:
          normalize_integer(Map.get(bollinger, :period), @default_indicators.bollinger.period),
        deviations:
          normalize_number(
            Map.get(bollinger, :deviations),
            @default_indicators.bollinger.deviations
          )
      }
    }
  end

  defp normalize_strategy(strategy) do
    strategy = normalize_options(strategy)

    %{
      fast_period: normalize_integer(Map.get(strategy, :fast_period), 5),
      slow_period: normalize_integer(Map.get(strategy, :slow_period), 20),
      initial_cash: normalize_number(Map.get(strategy, :initial_cash), 10_000.0)
    }
  end

  defp normalize_field(value) when is_atom(value), do: value

  defp normalize_field(value) when is_binary(value) do
    key = value |> String.downcase() |> String.replace("-", "_")
    Map.get(@known_fields, key, :close)
  end

  defp normalize_field(_value), do: :close

  defp normalize_operator(value)
       when value in [:above, :below, :at_or_above, :at_or_below, :crosses_above, :crosses_below],
       do: value

  defp normalize_operator(value) when is_binary(value) do
    case value |> String.downcase() |> String.replace("-", "_") do
      ">" -> :above
      "above" -> :above
      "<" -> :below
      "below" -> :below
      ">=" -> :at_or_above
      "at_or_above" -> :at_or_above
      "<=" -> :at_or_below
      "at_or_below" -> :at_or_below
      "crosses_above" -> :crosses_above
      "crosses_below" -> :crosses_below
      _ -> :above
    end
  end

  defp normalize_operator(_value), do: :above

  defp normalize_severity(value) when value in [:info, :warning, :critical], do: value

  defp normalize_severity(value) when is_binary(value) do
    case String.downcase(value) do
      "critical" -> :critical
      "warning" -> :warning
      _ -> :info
    end
  end

  defp normalize_severity(_value), do: :info

  defp normalize_options(opts) when is_list(opts), do: Map.new(opts)

  defp normalize_options(opts) when is_map(opts) do
    Enum.reduce(opts, %{}, fn
      {key, value}, acc when is_atom(key) -> Map.put(acc, key, value)
      {"symbol", value}, acc -> Map.put(acc, :symbol, value)
      {"timeframe", value}, acc -> Map.put(acc, :timeframe, value)
      {"indicators", value}, acc -> Map.put(acc, :indicators, value)
      {"alerts", value}, acc -> Map.put(acc, :alerts, value)
      {"strategy", value}, acc -> Map.put(acc, :strategy, value)
      {"timeframes", value}, acc -> Map.put(acc, :timeframes, value)
      {"sma", value}, acc -> Map.put(acc, :sma, value)
      {"ema", value}, acc -> Map.put(acc, :ema, value)
      {"rsi", value}, acc -> Map.put(acc, :rsi, value)
      {"macd", value}, acc -> Map.put(acc, :macd, value)
      {"bollinger", value}, acc -> Map.put(acc, :bollinger, value)
      {"fast_period", value}, acc -> Map.put(acc, :fast_period, value)
      {"slow_period", value}, acc -> Map.put(acc, :slow_period, value)
      {"initial_cash", value}, acc -> Map.put(acc, :initial_cash, value)
      {"fast", value}, acc -> Map.put(acc, :fast, value)
      {"slow", value}, acc -> Map.put(acc, :slow, value)
      {"signal", value}, acc -> Map.put(acc, :signal, value)
      {"period", value}, acc -> Map.put(acc, :period, value)
      {"deviations", value}, acc -> Map.put(acc, :deviations, value)
      {_key, _value}, acc -> acc
    end)
  end

  defp normalize_options(_opts), do: %{}

  defp fetch_value(map, key) when is_map(map) and is_atom(key) do
    cond do
      Map.has_key?(map, key) -> Map.get(map, key)
      Map.has_key?(map, Atom.to_string(key)) -> Map.get(map, Atom.to_string(key))
      true -> nil
    end
  end

  defp normalize_time(value) when is_integer(value), do: {:ok, value}

  defp normalize_time(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> {:ok, integer}
      _ -> {:ok, value}
    end
  end

  defp normalize_time(_value), do: :error

  defp normalize_integer(value, _default) when is_integer(value) and value > 0, do: value

  defp normalize_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} when integer > 0 -> integer
      _ -> default
    end
  end

  defp normalize_integer(_value, default), do: default

  defp normalize_number(value, default) do
    case normalize_number(value) do
      {:ok, number} -> number
      :error -> default
    end
  end

  defp normalize_number(value) when is_integer(value), do: {:ok, value / 1}
  defp normalize_number(value) when is_float(value), do: {:ok, value}

  defp normalize_number(value) when is_binary(value) do
    case Float.parse(value) do
      {number, ""} -> {:ok, number}
      _ -> :error
    end
  end

  defp normalize_number(_value), do: :error
end
