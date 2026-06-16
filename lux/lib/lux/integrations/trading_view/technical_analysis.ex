defmodule Lux.Integrations.TradingView.TechnicalAnalysis do
  @moduledoc """
  Technical-analysis helpers for TradingView-style OHLCV data.

  The functions operate on normalized candle maps and return chart-ready series
  that can be used by Lux prisms, dashboards, or downstream TradingView widgets.
  """

  @type candle :: %{
          time: String.t() | integer(),
          open: number(),
          high: number(),
          low: number(),
          close: number(),
          volume: number()
        }

  @spec normalize_candles([map()]) :: {:ok, [candle()]} | {:error, String.t()}
  def normalize_candles(candles) when is_list(candles) do
    candles
    |> Enum.reduce_while({:ok, []}, fn candle, {:ok, acc} ->
      case normalize_candle(candle) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, normalized} -> {:ok, Enum.reverse(normalized)}
      error -> error
    end
  end

  def normalize_candles(_), do: {:error, "candles must be a list"}

  @spec sma([number()], pos_integer()) :: [number() | nil]
  def sma(values, period) when is_list(values) and is_integer(period) and period > 0 do
    values
    |> Enum.with_index()
    |> Enum.map(fn {_value, index} ->
      if index + 1 < period do
        nil
      else
        values
        |> Enum.slice((index + 1 - period)..index)
        |> average()
      end
    end)
  end

  @spec ema([number()], pos_integer()) :: [number() | nil]
  def ema(values, period) when is_list(values) and is_integer(period) and period > 0 do
    multiplier = 2 / (period + 1)

    values
    |> Enum.with_index()
    |> Enum.reduce([], fn {value, index}, acc ->
      next =
        cond do
          index + 1 < period -> nil
          index + 1 == period -> values |> Enum.slice(0, period) |> average()
          true -> value * multiplier + hd(acc) * (1 - multiplier)
        end

      [next | acc]
    end)
    |> Enum.reverse()
  end

  @spec rsi([number()], pos_integer()) :: [number() | nil]
  def rsi(values, period \\ 14) when is_list(values) and is_integer(period) and period > 0 do
    deltas =
      values
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [previous, current] -> current - previous end)

    [nil | rsi_from_deltas(deltas, period)]
  end

  @spec analyze([map()], keyword()) :: {:ok, map()} | {:error, String.t()}
  def analyze(candles, opts \\ []) do
    with {:ok, normalized} <- normalize_candles(candles) do
      closes = Enum.map(normalized, & &1.close)
      sma_period = Keyword.get(opts, :sma_period, 20)
      ema_period = Keyword.get(opts, :ema_period, 20)
      rsi_period = Keyword.get(opts, :rsi_period, 14)

      indicators = %{
        sma: chart_series(normalized, sma(closes, sma_period)),
        ema: chart_series(normalized, ema(closes, ema_period)),
        rsi: chart_series(normalized, rsi(closes, rsi_period))
      }

      {:ok,
       %{
         candles: normalized,
         indicators: indicators,
         latest_signal: signal(indicators),
         alerts: alerts(indicators)
       }}
    end
  end

  @spec backtest_sma_cross([map()], pos_integer(), pos_integer()) ::
          {:ok, map()} | {:error, String.t()}
  def backtest_sma_cross(candles, fast_period \\ 5, slow_period \\ 20) do
    with {:ok, normalized} <- normalize_candles(candles) do
      closes = Enum.map(normalized, & &1.close)
      fast = sma(closes, fast_period)
      slow = sma(closes, slow_period)

      trades =
        normalized
        |> Enum.zip(fast)
        |> Enum.zip(slow)
        |> Enum.map(fn {{candle, fast_value}, slow_value} ->
          %{
            time: candle.time,
            close: candle.close,
            fast: fast_value,
            slow: slow_value,
            signal: crossover_signal(fast_value, slow_value)
          }
        end)

      {:ok,
       %{
         strategy: "sma_cross",
         fast_period: fast_period,
         slow_period: slow_period,
         trades: trades,
         signal_counts: trades |> Enum.map(& &1.signal) |> Enum.frequencies()
       }}
    end
  end

  defp normalize_candle(candle) do
    with {:ok, time} <- fetch_any(candle, :time),
         {:ok, open} <- fetch_number(candle, :open),
         {:ok, high} <- fetch_number(candle, :high),
         {:ok, low} <- fetch_number(candle, :low),
         {:ok, close} <- fetch_number(candle, :close),
         {:ok, volume} <- fetch_number(candle, :volume) do
      {:ok, %{time: time, open: open, high: high, low: low, close: close, volume: volume}}
    end
  end

  defp rsi_from_deltas(deltas, period) do
    deltas
    |> Enum.with_index()
    |> Enum.map(fn {_delta, index} ->
      if index + 1 < period do
        nil
      else
        window = Enum.slice(deltas, (index + 1 - period)..index)
        gains = window |> Enum.map(&max(&1, 0)) |> average()
        losses = window |> Enum.map(&abs(min(&1, 0))) |> average()

        cond do
          losses == 0 -> 100.0
          true -> 100 - 100 / (1 + gains / losses)
        end
      end
    end)
  end

  defp chart_series(candles, values) do
    candles
    |> Enum.zip(values)
    |> Enum.map(fn {candle, value} -> %{time: candle.time, value: value} end)
  end

  defp signal(%{sma: sma_series, ema: ema_series, rsi: rsi_series}) do
    latest_sma = latest_value(sma_series)
    latest_ema = latest_value(ema_series)
    latest_rsi = latest_value(rsi_series)

    cond do
      latest_rsi && latest_rsi >= 70 -> :overbought
      latest_rsi && latest_rsi <= 30 -> :oversold
      latest_ema && latest_sma && latest_ema > latest_sma -> :bullish
      latest_ema && latest_sma && latest_ema < latest_sma -> :bearish
      true -> :neutral
    end
  end

  defp alerts(indicators) do
    case signal(indicators) do
      :overbought -> [%{severity: :warning, message: "RSI is overbought"}]
      :oversold -> [%{severity: :warning, message: "RSI is oversold"}]
      :bullish -> [%{severity: :info, message: "EMA is above SMA"}]
      :bearish -> [%{severity: :info, message: "EMA is below SMA"}]
      :neutral -> []
    end
  end

  defp latest_value(series) do
    series
    |> Enum.reverse()
    |> Enum.find_value(& &1.value)
  end

  defp crossover_signal(nil, _slow), do: :hold
  defp crossover_signal(_fast, nil), do: :hold
  defp crossover_signal(fast, slow) when fast > slow, do: :long
  defp crossover_signal(fast, slow) when fast < slow, do: :short
  defp crossover_signal(_fast, _slow), do: :hold

  defp average(values), do: Enum.sum(values) / length(values)

  defp fetch_any(map, key) do
    case Map.get(map, key, Map.get(map, to_string(key))) do
      nil -> {:error, "Missing candle #{key}"}
      value -> {:ok, value}
    end
  end

  defp fetch_number(map, key) do
    case Map.get(map, key, Map.get(map, to_string(key))) do
      value when is_number(value) -> {:ok, value}
      _ -> {:error, "Candle #{key} must be numeric"}
    end
  end
end
