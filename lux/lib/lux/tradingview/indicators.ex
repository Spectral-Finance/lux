defmodule Lux.TradingView.Indicators do
  @moduledoc """
  High-precision technical indicator calculation engine for TradingView chart analysis:
  - SMA (Simple Moving Average)
  - EMA (Exponential Moving Average)
  - RSI (Relative Strength Index with Wilder smoothing and zero-loss protection)
  - MACD (Moving Average Convergence Divergence)
  - Bollinger Bands (Upper, Middle, Lower, Bandwidth %, and %B)
  - ATR (Average True Range)
  - Stochastic Oscillator (%K and %D)
  - SuperTrend (ATR-based dynamic volatility trailing trend)
  """

  @doc """
  Calculates the Simple Moving Average (SMA) of period `n` for a list of close prices.
  """
  @spec calculate_sma(list(number()), pos_integer()) :: float() | nil
  def calculate_sma(prices, period)
      when is_list(prices) and length(prices) >= period and period > 0 do
    prices
    |> Enum.take(-period)
    |> Enum.sum()
    |> Kernel./(period)
    |> Float.round(4)
  end

  def calculate_sma(_prices, _period), do: nil

  @doc """
  Calculates the Exponential Moving Average (EMA) of period `n` for a list of close prices.
  Uses the standard multiplier: 2 / (period + 1).
  """
  @spec calculate_ema(list(number()), pos_integer()) :: float() | nil
  def calculate_ema(prices, period)
      when is_list(prices) and length(prices) >= period and period > 0 do
    multiplier = 2.0 / (period + 1)
    # Seed the initial EMA with the SMA of the first `period` prices
    initial_sma =
      prices
      |> Enum.take(period)
      |> Enum.sum()
      |> Kernel./(period)

    # Fold over the remaining prices
    remaining = Enum.drop(prices, period)

    final_ema =
      Enum.reduce(remaining, initial_sma, fn price, prev_ema ->
        (price - prev_ema) * multiplier + prev_ema
      end)

    Float.round(final_ema, 4)
  end

  def calculate_ema(_prices, _period), do: nil

  @doc """
  Calculates Relative Strength Index (RSI) using J. Welles Wilder's smoothing algorithm.
  Period defaults to 14.
  Handles zero-loss, zero-gain, and flat price series gracefully.
  """
  @spec calculate_rsi(list(number()), pos_integer()) :: float()
  def calculate_rsi(prices, period \\ 14)

  def calculate_rsi(prices, period)
      when is_list(prices) and length(prices) > period and period > 0 do
    # Calculate price changes between consecutive periods
    changes =
      prices
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [prev, curr] -> curr - prev end)

    # Initial average gain and loss over the first `period` changes
    {first_gains, first_losses} =
      changes
      |> Enum.take(period)
      |> Enum.reduce({0.0, 0.0}, fn change, {g, l} ->
        if change > 0, do: {g + change, l}, else: {g, l + abs(change)}
      end)

    init_avg_gain = first_gains / period
    init_avg_loss = first_losses / period

    # Apply Wilder's smoothing to remaining changes
    remaining_changes = Enum.drop(changes, period)

    {final_avg_gain, final_avg_loss} =
      Enum.reduce(remaining_changes, {init_avg_gain, init_avg_loss}, fn change,
                                                                        {prev_g, prev_l} ->
        curr_g = if change > 0, do: change, else: 0.0
        curr_l = if change < 0, do: abs(change), else: 0.0

        new_g = (prev_g * (period - 1) + curr_g) / period
        new_l = (prev_l * (period - 1) + curr_l) / period

        {new_g, new_l}
      end)

    cond do
      final_avg_loss == 0.0 and final_avg_gain == 0.0 ->
        50.0

      final_avg_loss == 0.0 ->
        100.0

      final_avg_gain == 0.0 ->
        0.0

      true ->
        rs = final_avg_gain / final_avg_loss
        rsi = 100.0 - 100.0 / (1.0 + rs)
        Float.round(rsi, 2)
    end
  end

  def calculate_rsi(_prices, _period), do: 50.0

  @doc """
  Calculates Moving Average Convergence Divergence (MACD):
  - Fast EMA (default 12)
  - Slow EMA (default 26)
  - MACD Line = Fast EMA - Slow EMA
  - Signal Line = 9-period EMA of MACD Line
  - Histogram = MACD Line - Signal Line
  """
  @spec calculate_macd(list(number()), pos_integer(), pos_integer(), pos_integer()) :: %{
          macd_line: float(),
          signal_line: float(),
          histogram: float(),
          trend: :bullish | :bearish | :neutral
        }
  def calculate_macd(prices, fast_p \\ 12, slow_p \\ 26, signal_p \\ 9)

  def calculate_macd(prices, fast_p, slow_p, signal_p)
      when is_list(prices) and length(prices) >= slow_p + signal_p do
    # Generate MACD series over rolling windows
    macd_series =
      (slow_p + signal_p)..length(prices)
      |> Enum.map(fn len ->
        sub = Enum.take(prices, len)
        fast_ema = calculate_ema(sub, fast_p)
        slow_ema = calculate_ema(sub, slow_p)
        fast_ema - slow_ema
      end)

    macd_line = List.last(macd_series) || 0.0
    signal_line = calculate_ema(macd_series, signal_p) || 0.0
    histogram = Float.round(macd_line - signal_line, 4)

    trend =
      cond do
        histogram > 0.0 -> :bullish
        histogram < 0.0 -> :bearish
        true -> :neutral
      end

    %{
      macd_line: Float.round(macd_line, 4),
      signal_line: Float.round(signal_line, 4),
      histogram: histogram,
      trend: trend
    }
  end

  def calculate_macd(_prices, _fast_p, _slow_p, _signal_p) do
    %{
      macd_line: 0.0,
      signal_line: 0.0,
      histogram: 0.0,
      trend: :neutral
    }
  end

  @doc """
  Calculates Bollinger Bands (Middle, Upper, Lower, Bandwidth %, %B):
  - Middle = SMA(period)
  - Upper = Middle + (multiplier * std_dev)
  - Lower = Middle - (multiplier * std_dev)
  """
  @spec calculate_bollinger_bands(list(number()), pos_integer(), float()) :: %{
          middle: float(),
          upper: float(),
          lower: float(),
          bandwidth_pct: float(),
          percent_b: float()
        }
  def calculate_bollinger_bands(prices, period \\ 20, multiplier \\ 2.0)

  def calculate_bollinger_bands(prices, period, multiplier)
      when is_list(prices) and length(prices) >= period and period > 0 do
    window = Enum.take(prices, -period)
    current_price = List.last(window) * 1.0
    mean = Enum.sum(window) / period

    variance =
      window
      |> Enum.map(fn p -> :math.pow(p - mean, 2) end)
      |> Enum.sum()
      |> Kernel./(period)

    std_dev = :math.sqrt(variance)

    upper = mean + multiplier * std_dev
    lower = mean - multiplier * std_dev

    bandwidth =
      if mean > 0, do: Float.round((upper - lower) / mean * 100.0, 2), else: 0.0

    percent_b =
      if upper != lower,
        do: Float.round((current_price - lower) / (upper - lower), 4),
        else: 0.5

    %{
      middle: Float.round(mean, 4),
      upper: Float.round(upper, 4),
      lower: Float.round(lower, 4),
      bandwidth_pct: bandwidth,
      percent_b: percent_b
    }
  end

  def calculate_bollinger_bands(prices, _period, _multiplier) do
    last_p = (List.last(prices) || 0.0) * 1.0

    %{
      middle: last_p,
      upper: last_p,
      lower: last_p,
      bandwidth_pct: 0.0,
      percent_b: 0.5
    }
  end

  @doc """
  Calculates Average True Range (ATR) of period N for historical OHLCV bars.
  True Range = max(H - L, abs(H - prev_C), abs(L - prev_C)).
  """
  @spec calculate_atr(list(map()), pos_integer()) :: float()
  def calculate_atr(candles, period \\ 14)

  def calculate_atr(candles, period) when is_list(candles) and length(candles) > period do
    trs =
      candles
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [prev, curr] ->
        h = curr[:high] || curr["high"] || 0.0
        l = curr[:low] || curr["low"] || 0.0
        prev_c = prev[:close] || prev["close"] || 0.0

        hl = h - l
        hc = abs(h - prev_c)
        lc = abs(l - prev_c)

        Enum.max([hl, hc, lc])
      end)

    # Initial SMA of True Range
    init_atr = trs |> Enum.take(period) |> Enum.sum() |> Kernel./(period)

    # Wilder smoothing for remainder
    remaining = Enum.drop(trs, period)

    final_atr =
      Enum.reduce(remaining, init_atr, fn tr, prev_atr ->
        (prev_atr * (period - 1) + tr) / period
      end)

    Float.round(final_atr, 4)
  end

  def calculate_atr(_candles, _period), do: 0.0

  @doc """
  Calculates Stochastic Oscillator (%K and %D) for candlestick series.
  %K = (Current Close - Lowest Low) / (Highest High - Lowest Low) * 100.
  %D = 3-period SMA of %K.
  """
  @spec calculate_stochastic(list(map()), pos_integer(), pos_integer()) :: %{
          k: float(),
          d: float()
        }
  def calculate_stochastic(candles, k_period \\ 14, d_period \\ 3)

  def calculate_stochastic(candles, k_period, d_period)
      when is_list(candles) and length(candles) >= k_period + d_period do
    k_series =
      k_period..length(candles)
      |> Enum.map(fn len ->
        window = Enum.take(candles, len) |> Enum.take(-k_period)
        curr = List.last(window)
        curr_close = curr[:close] || curr["close"] || 0.0

        highest_high =
          window
          |> Enum.map(fn c -> c[:high] || c["high"] || 0.0 end)
          |> Enum.max()

        lowest_low =
          window
          |> Enum.map(fn c -> c[:low] || c["low"] || 0.0 end)
          |> Enum.min()

        denom = highest_high - lowest_low

        if denom > 0 do
          (curr_close - lowest_low) / denom * 100.0
        else
          50.0
        end
      end)

    current_k = List.last(k_series) || 50.0

    current_d =
      k_series
      |> Enum.take(-d_period)
      |> Enum.sum()
      |> Kernel./(d_period)

    %{
      k: Float.round(current_k, 2),
      d: Float.round(current_d, 2)
    }
  end

  def calculate_stochastic(_candles, _k_period, _d_period) do
    %{k: 50.0, d: 50.0}
  end

  @doc """
  Calculates SuperTrend volatility-adjusted trend direction and trailing band.
  """
  @spec calculate_supertrend(list(map()), pos_integer(), float()) :: %{
          trend: :bullish | :bearish,
          band: float()
        }
  def calculate_supertrend(candles, period \\ 10, multiplier \\ 3.0)

  def calculate_supertrend(candles, period, multiplier)
      when is_list(candles) and length(candles) > period do
    atr = calculate_atr(candles, period)
    last_candle = List.last(candles)
    high = last_candle[:high] || last_candle["high"] || 0.0
    low = last_candle[:low] || last_candle["low"] || 0.0
    close = last_candle[:close] || last_candle["close"] || 0.0

    basic_upper = (high + low) / 2.0 + multiplier * atr
    basic_lower = (high + low) / 2.0 - multiplier * atr

    if close >= basic_upper do
      %{trend: :bullish, band: Float.round(basic_lower, 4)}
    else
      %{trend: :bearish, band: Float.round(basic_upper, 4)}
    end
  end

  def calculate_supertrend(candles, _period, _multiplier) do
    last_close =
      case List.last(candles) do
        nil -> 0.0
        c -> c[:close] || c["close"] || 0.0
      end

    %{trend: :neutral, band: last_close}
  end

  # =========================================================================
  # Series APIs and Comprehensive Analysis
  # =========================================================================

  @doc """
  Calculates running SMA series.
  """
  def sma(prices, period) when is_list(prices) and length(prices) >= period and period > 0 do
    series =
      period..length(prices)
      |> Enum.map(fn len ->
        sub = Enum.take(prices, len)
        calculate_sma(sub, period)
      end)

    {:ok, series}
  end

  def sma(_prices, period) do
    {:error, "Insufficient data for SMA(#{period})"}
  end

  @doc """
  Calculates running EMA series.
  """
  def ema(prices, period) when is_list(prices) and length(prices) >= period and period > 0 do
    multiplier = 2.0 / (period + 1)
    initial_sma = prices |> Enum.take(period) |> Enum.sum() |> Kernel./(period)
    remaining = Enum.drop(prices, period)

    series =
      Enum.scan(remaining, initial_sma, fn price, prev_ema ->
        (price - prev_ema) * multiplier + prev_ema
      end)

    {:ok, [Float.round(initial_sma, 4) | Enum.map(series, &Float.round(&1, 4))]}
  end

  def ema(_prices, period) do
    {:error, "Insufficient data for EMA(#{period})"}
  end

  @doc """
  Calculates running RSI series with Wilder smoothing.
  """
  def rsi(prices, period \\ 14)

  def rsi(prices, period) when is_list(prices) and length(prices) > period and period > 0 do
    diffs = prices |> Enum.chunk_every(2, 1, :discard) |> Enum.map(fn [a, b] -> b - a end)

    if Enum.all?(diffs, &(&1 == 0.0 or &1 == 0)) do
      {:ok, [50.0]}
    else
      series =
        (period + 1)..length(prices)
        |> Enum.map(fn len ->
          sub = Enum.take(prices, len)
          calculate_rsi(sub, period)
        end)

      {:ok, series}
    end
  end

  def rsi(_prices, period) do
    {:error, "Insufficient data for RSI(#{period})"}
  end

  @doc """
  Calculates running MACD series (macd line, signal line, histogram).
  """
  def macd(prices, fast_p \\ 12, slow_p \\ 26, signal_p \\ 9)

  def macd(prices, fast_p, slow_p, signal_p)
      when is_list(prices) and length(prices) >= slow_p + signal_p do
    macd_series =
      slow_p..length(prices)
      |> Enum.map(fn len ->
        sub = Enum.take(prices, len)
        fast = calculate_ema(sub, fast_p)
        slow = calculate_ema(sub, slow_p)
        fast - slow
      end)

    {:ok, signal_series} = ema(macd_series, signal_p)
    macd_trimmed = Enum.take(macd_series, -length(signal_series))

    hist_series =
      Enum.zip(macd_trimmed, signal_series)
      |> Enum.map(fn {m, s} -> Float.round(m - s, 4) end)

    {:ok,
     %{
       macd: Enum.map(macd_trimmed, &Float.round(&1, 4)),
       signal: signal_series,
       histogram: hist_series
     }}
  end

  def macd(_prices, _fast_p, _slow_p, _signal_p) do
    {:error, "Insufficient data for MACD"}
  end

  @doc """
  Calculates running Bollinger Bands series (middle, upper, lower, percent_b, bandwidth).
  """
  def bollinger_bands(prices, period \\ 20, multiplier \\ 2.0)

  def bollinger_bands(prices, period, multiplier)
      when is_list(prices) and length(prices) >= period and period > 0 do
    bands =
      period..length(prices)
      |> Enum.map(fn len ->
        sub = Enum.take(prices, len)
        calculate_bollinger_bands(sub, period, multiplier)
      end)

    {:ok,
     %{
       middle: Enum.map(bands, & &1.middle),
       upper: Enum.map(bands, & &1.upper),
       lower: Enum.map(bands, & &1.lower),
       percent_b: Enum.map(bands, & &1.percent_b),
       bandwidth: Enum.map(bands, & &1.bandwidth_pct)
     }}
  end

  def bollinger_bands(_prices, period, _mult) do
    {:error, "Insufficient data for Bollinger Bands(#{period})"}
  end

  @doc """
  Calculates running ATR series.
  """
  def atr(candles, period \\ 14)

  def atr(candles, period) when is_list(candles) and length(candles) > period do
    series =
      (period + 1)..length(candles)
      |> Enum.map(fn len ->
        sub = Enum.take(candles, len)
        calculate_atr(sub, period)
      end)

    {:ok, series}
  end

  def atr(_candles, period) do
    {:error, "Insufficient data for ATR(#{period})"}
  end

  @doc """
  Calculates running Stochastic series (%K and %D).
  """
  def stochastic(candles, k_period \\ 14, d_period \\ 3, _smooth_k \\ 3)

  def stochastic(candles, k_period, d_period, _smooth_k)
      when is_list(candles) and length(candles) >= k_period + d_period do
    k_series =
      k_period..length(candles)
      |> Enum.map(fn len ->
        sub = Enum.take(candles, len)
        curr = List.last(sub)
        curr_close = curr[:close] || curr["close"] || 0.0
        highs = Enum.map(sub, fn c -> c[:high] || c["high"] || 0.0 end)
        lows = Enum.map(sub, fn c -> c[:low] || c["low"] || 0.0 end)
        hh = Enum.max(highs)
        ll = Enum.min(lows)
        denom = hh - ll
        if denom > 0, do: Float.round((curr_close - ll) / denom * 100.0, 2), else: 50.0
      end)

    d_series =
      d_period..length(k_series)
      |> Enum.map(fn len ->
        sub = Enum.take(k_series, len) |> Enum.take(-d_period)
        Float.round(Enum.sum(sub) / d_period, 2)
      end)

    {:ok, %{k: k_series, d: d_series}}
  end

  def stochastic(_candles, _k_p, _d_p, _s_k) do
    {:error, "Insufficient data for Stochastic"}
  end

  @doc """
  Calculates running SuperTrend series (supertrend and direction).
  """
  def supertrend(candles, period \\ 10, multiplier \\ 3.0)

  def supertrend(candles, period, multiplier)
      when is_list(candles) and length(candles) > 0 do
    results =
      Enum.map(1..length(candles), fn len ->
        sub = Enum.take(candles, len)
        res = calculate_supertrend(sub, period, multiplier)
        dir = if res.trend == :bullish, do: 1, else: -1
        {res.band, dir}
      end)

    {:ok,
     %{
       supertrend: Enum.map(results, &elem(&1, 0)),
       direction: Enum.map(results, &elem(&1, 1))
     }}
  end

  @doc """
  Calculates comprehensive technical analysis across all indicators.
  """
  def calculate_all(candles_or_prices, opts \\ [])

  def calculate_all(data, opts) when is_list(data) and length(data) > 0 do
    prices =
      Enum.map(data, fn
        %{} = c -> c[:close] || c["close"] || 0.0
        p when is_number(p) -> p * 1.0
        _ -> 0.0
      end)

    current_price = (List.last(prices) || 0.0) * 1.0
    rsi_p = Keyword.get(opts, :rsi_period, 14)
    bb_p = Keyword.get(opts, :bb_period, 20)

    rsi = calculate_rsi(prices, rsi_p)
    macd = calculate_macd(prices)
    bb = calculate_bollinger_bands(prices, bb_p)
    sma20 = calculate_sma(prices, 20)
    ema20 = calculate_ema(prices, 20)

    is_candles = is_map(hd(data))

    atr = if is_candles, do: calculate_atr(data, 14), else: 0.0
    stoch = if is_candles, do: calculate_stochastic(data), else: %{k: 50.0, d: 50.0}

    {:ok,
     %{
       current_price: current_price,
       rsi: rsi,
       macd: macd,
       bollinger: bb,
       sma_20: sma20,
       ema_20: ema20,
       atr: atr,
       stochastic: stoch
     }}
  end

  def calculate_all(_data, _opts) do
    {:error, "Empty or invalid market data provided"}
  end
end
