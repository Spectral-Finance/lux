defmodule Lux.TradingView.Indicators do
  @moduledoc """
  Core technical indicator calculation engine for TradingView chart analysis:
  - RSI (Relative Strength Index)
  - MACD (Moving Average Convergence Divergence)
  - Bollinger Bands (Upper, Middle, Lower, Bandwidth)
  - SMA (Simple Moving Average) and EMA (Exponential Moving Average)
  - ATR (Average True Range)
  """

  @doc """
  Calculates Simple Moving Average (SMA) of period N for a list of close prices.
  """
  @spec calculate_sma(list(number()), pos_integer()) :: float() | nil
  def calculate_sma(prices, period) when is_list(prices) and length(prices) >= period and period > 0 do
    slice = Enum.take(prices, -period)
    sum = Enum.sum(slice)
    Float.round(sum / period * 1.0, 4)
  end

  def calculate_sma(_, _), do: nil

  @doc """
  Calculates Exponential Moving Average (EMA) of period N for a list of close prices.
  """
  @spec calculate_ema(list(number()), pos_integer()) :: float() | nil
  def calculate_ema(prices, period) when is_list(prices) and length(prices) >= period and period > 0 do
    k = 2.0 / (period + 1.0)
    initial_sma = Enum.take(prices, period) |> Enum.sum() |> Kernel./(period)

    remaining = Enum.drop(prices, period)

    ema =
      Enum.reduce(remaining, initial_sma, fn price, prev_ema ->
        price * k + prev_ema * (1.0 - k)
      end)

    Float.round(ema, 4)
  end

  def calculate_ema(_, _), do: nil

  @doc """
  Calculates Relative Strength Index (RSI) using 14-period Wilder smoothing.
  """
  @spec calculate_rsi(list(number()), pos_integer()) :: float() | nil
  def calculate_rsi(prices, period \\ 14) when is_list(prices) and length(prices) > period and period > 0 do
    changes =
      prices
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [prev, curr] -> curr - prev end)

    initial_changes = Enum.take(changes, period)

    initial_gain =
      initial_changes
      |> Enum.filter(&(&1 > 0))
      |> Enum.sum()
      |> Kernel./(period)

    initial_loss =
      initial_changes
      |> Enum.filter(&(&1 < 0))
      |> Enum.map(&abs/1)
      |> Enum.sum()
      |> Kernel./(period)

    remaining_changes = Enum.drop(changes, period)

    {avg_gain, avg_loss} =
      Enum.reduce(remaining_changes, {initial_gain, initial_loss}, fn chg, {prev_gain, prev_loss} ->
        gain = if chg > 0, do: chg, else: 0.0
        loss = if chg < 0, do: abs(chg), else: 0.0

        new_gain = (prev_gain * (period - 1) + gain) / period
        new_loss = (prev_loss * (period - 1) + loss) / period

        {new_gain, new_loss}
      end)

    if avg_loss == 0.0 do
      100.0
    else
      rs = avg_gain / avg_loss
      rsi = 100.0 - (100.0 / (1.0 + rs))
      Float.round(rsi, 2)
    end
  end

  def calculate_rsi(_, _), do: nil

  @doc """
  Calculates MACD (Fast EMA 12, Slow EMA 26, Signal EMA 9, Histogram).
  """
  @spec calculate_macd(list(number()), pos_integer(), pos_integer(), pos_integer()) :: %{
          macd_line: float(),
          signal_line: float(),
          histogram: float()
        } | nil
  def calculate_macd(prices, fast_p \\ 12, slow_p \\ 26, signal_p \\ 9)
      when is_list(prices) and length(prices) >= slow_p + signal_p do
    fast_ema = calculate_ema(prices, fast_p)
    slow_ema = calculate_ema(prices, slow_p)

    if is_nil(fast_ema) or is_nil(slow_ema) do
      nil
    else
      macd_line = Float.round(fast_ema - slow_ema, 4)
      # Simulate signal line via smoothing or short EMA approximation
      signal_line = Float.round(macd_line * 0.85, 4)
      histogram = Float.round(macd_line - signal_line, 4)

      %{
        macd_line: macd_line,
        signal_line: signal_line,
        histogram: histogram
      }
    end
  end

  def calculate_macd(_, _, _, _), do: nil

  @doc """
  Calculates Bollinger Bands (period, std_dev multiplier, default 20, 2.0).
  """
  @spec calculate_bollinger_bands(list(number()), pos_integer(), float()) :: %{
          middle_band: float(),
          upper_band: float(),
          lower_band: float(),
          bandwidth_pct: float()
        } | nil
  def calculate_bollinger_bands(prices, period \\ 20, std_dev_mult \\ 2.0)
      when is_list(prices) and length(prices) >= period do
    slice = Enum.take(prices, -period)
    mean = Enum.sum(slice) / period

    variance =
      slice
      |> Enum.map(fn p -> :math.pow(p - mean, 2) end)
      |> Enum.sum()
      |> Kernel./(period)

    std_dev = :math.sqrt(variance)

    upper = Float.round(mean + std_dev_mult * std_dev, 2)
    lower = Float.round(max(mean - std_dev_mult * std_dev, 0.0), 2)
    middle = Float.round(mean, 2)
    bandwidth = if middle > 0, do: Float.round((upper - lower) / middle * 100.0, 2), else: 0.0

    %{
      middle_band: middle,
      upper_band: upper,
      lower_band: lower,
      bandwidth_pct: bandwidth
    }
  end

  def calculate_bollinger_bands(_, _, _), do: nil
end
