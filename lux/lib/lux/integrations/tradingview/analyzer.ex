defmodule Lux.Integrations.TradingView.Analyzer do
  @moduledoc """
  Technical analysis engine for TradingView-compatible signals.

  Implements core TA-Lib indicators in pure Elixir:
  - SMA (Simple Moving Average)
  - EMA (Exponential Moving Average)
  - RSI (Relative Strength Index)
  - MACD (Moving Average Convergence Divergence)
  - Bollinger Bands
  - ADX (Average Directional Index)
  - Signal generation from combined indicators
  """

  @type price_list :: [float()]

  @doc """
  Calculates Simple Moving Average with given window size.

  ## Examples

      iex> Analyzer.sma([1, 2, 3, 4, 5], 3)
      [2.0, 3.0, 4.0]
  """
  @spec sma(price_list(), pos_integer()) :: [float()]
  def sma(prices, window) when is_list(prices) and is_integer(window) and window > 0 do
    do_sma(prices, window, [])
  end

  defp do_sma(prices, window, acc) do
    case sliding_window(prices, window) do
      [window_vals | _rest] ->
        avg = Enum.sum(window_vals) / length(window_vals)
        do_sma(rest, window, [avg | acc])
      [] ->
        :lists.reverse(acc)
    end
  end

  @doc """
  Calculates Exponential Moving Average with given window size.

  ## Examples

      iex> Analyzer.ema([1, 2, 3, 4, 5], 3)
      [1.0, 1.5, 2.25, 3.125, 4.0625]
  """
  @spec ema(price_list(), pos_integer()) :: [float()]
  def ema(prices, window) when is_list(prices) and is_integer(window) and window > 0 do
    smoothing = 2.0 / (window + 1)
    [first | rest] = prices
    results =
      rest
      |> Enum.reduce(%{prev: first, acc: [first]}, fn price, %{prev: prev} = state ->
        current = price * smoothing + prev * (1 - smoothing)
        %{state | prev: current, acc: [current | state.acc]}
      end)
    :lists.reverse(results.acc)
  end

  @doc """
  Calculates Relative Strength Index.

  ## Examples

      iex> prices = [100, 101, 102, 103, 104, 103, 102, 101, 100, 99]
      iex> rsi = Analyzer.rsi(prices, 14)
      iex> is_number(rsi)
      true
  """
  @spec rsi(price_list(), pos_integer()) :: float()
  def rsi(prices, window \\ 14) when is_list(prices) and is_integer(window) and window > 0 do
    changes = price_changes(prices)
    if length(changes) < window do
      50.0
    else
      gains = changes |> Enum.filter(&(&1 > 0)) |> Enum.map(& &1)
      losses = changes |> Enum.filter(&(&1 < 0)) |> Enum.map(fn x -> abs(x) end)
      avg_gain = if Enum.empty?(gains), do: 0.0, else: Enum.sum(gains) / window
      avg_loss = if Enum.empty?(losses), do: 0.0, else: Enum.sum(losses) / window
      if avg_loss == 0 do
        100.0
      else
        rs = avg_gain / avg_loss
        100.0 - (100.0 / (1.0 + rs))
      end
    end
  end

  @doc """
  Calculates MACD line, signal line, and histogram.

  ## Examples

      iex> prices = Enum.to_list(1..30)
      iex> macd = Analyzer.macd(prices)
      iex> Map.has_key?(macd, :macd_line)
      true
  """
  @spec macd(price_list()) :: map()
  def macd(prices, fast_period \\ 12, slow_period \\ 26, signal_period \\ 9)
      when is_list(prices) and is_integer(fast_period) and is_integer(slow_period) and is_integer(signal_period) do
    ema_fast = ema(prices, fast_period)
    ema_slow = ema(prices, slow_period)
    min_len = min(length(ema_fast), length(ema_slow))
    macd_line =
      Enum.zip(Enum.take(ema_fast, min_len), Enum.take(ema_slow, min_len))
      |> Enum.map(fn {f, s} -> f - s end)
    signal_line = ema(macd_line, signal_period)
    min_len2 = min(length(macd_line), length(signal_line))
    histogram =
      Enum.zip(Enum.take(macd_line, min_len2), Enum.take(signal_line, min_len2))
      |> Enum.map(fn {m, s} -> m - s end)
    %{
      macd_line: macd_line,
      signal_line: signal_line,
      histogram: histogram,
      current_macd: List.last(macd_line) || 0.0,
      current_signal: List.last(signal_line) || 0.0,
      current_histogram: List.last(histogram) || 0.0
    }
  end

  @doc """
  Calculates Bollinger Bands (upper, middle/SMA, lower).

  ## Examples

      iex> prices = Enum.to_list(1..30)
      iex> bands = Analyzer.bollinger_bands(prices)
      iex> Map.has_key?(bands, :upper)
      true
  """
  @spec bollinger_bands(price_list(), non_neg_integer(), float()) :: map()
  def bollinger_bands(prices, window \\ 20, std_dev_mult \\ 2.0)
      when is_list(prices) and is_integer(window) and window >= 0 and is_float(std_dev_mult) do
    sma_values = sma(prices, window)
    bands =
      Enum.zip(sma_values, sliding_window_prices(prices, window))
      |> Enum.map(fn {sma, window_prices} ->
        variance =
          window_prices
          |> Enum.map(fn p ->
            diff = p - sma
            diff * diff
          end)
          |> Enum.sum()
          |> Kernel./(length(window_prices))
        std_dev = :math.sqrt(variance)
        %{
          upper: sma + std_dev_mult * std_dev,
          middle: sma,
          lower: sma - std_dev_mult * std_dev,
          std_dev: std_dev
        }
      end)
    current = List.last(bands) || %{upper: 0.0, middle: 0.0, lower: 0.0, std_dev: 0.0}
    %{
      upper: Enum.map(bands, & &1.upper),
      middle: Enum.map(bands, & &1.middle),
      lower: Enum.map(bands, & &1.lower),
      current_upper: current.upper,
      current_middle: current.middle,
      current_lower: current.lower,
      current_std_dev: current.std_dev
    }
  end

  @doc """
  Calculates ADX (Average Directional Index) using True Range and directional movement.

  ## Examples

      iex> highs = [100, 102, 101, 103, 105, 104, 106, 108, 107, 109, 110, 109, 111, 112, 110]
      iex> lows = [95, 96, 97, 95, 96, 98, 97, 99, 100, 98, 99, 101, 100, 101, 103]
      iex> closes = [98, 100, 99, 102, 104, 103, 105, 107, 106, 108, 109, 108, 110, 111, 109]
      iex> adx = Analyzer.adx(highs, lows, closes)
      iex> is_map(adx)
      true
  """
  @spec adx([float()], [float()], [float()], pos_integer()) :: map()
  def adx(highs, lows, closes, period \\ 14)
      when is_list(highs) and is_list(lows) and is_list(closes) and is_integer(period) and period > 0 do
    tr_data = calculate_true_range(highs, lows, closes)
    dm_data = calculate_directional_movement(highs, lows)
    smoothed_tr = smooth_series(tr_data, period)
    smoothed_plus_dm = smooth_series(dm_data.plus_dm, period)
    smoothed_minus_dm = smooth_series(dm_data.minus_dm, period)
    atr = smoothed_tr
    dx_values =
      Enum.zip(Enum.zip(smoothed_plus_dm, smoothed_minus_dm), atr)
      |> Enum.map(fn {{plus, minus}, _atr_val} ->
        if plus == 0 and minus == 0 do
          0.0
        else
          di_plus = if minus == 0, do: 100.0, else: (plus / (plus + minus)) * 100.0
          di_minus = if plus == 0, do: 100.0, else: (minus / (plus + minus)) * 100.0
          total = di_plus + di_minus
          if total == 0, do: 0.0, else: ((di_plus + di_minus) / 2.0)
        end
      end)
    smoothed_dx = smooth_series(dx_values, period)
    adx_values = smoothed_dx
    current_adx = List.last(adx_values) || 0.0
    current_plus = smoothed_plus_dm |> List.last() |> then(fn v -> v || 0.0 end)
    current_minus = smoothed_minus_dm |> List.last() |> then(fn v -> v || 0.0 end)
    %{
      adx: adx_values,
      di_plus: smoothed_plus_dm,
      di_minus: smoothed_minus_dm,
      current_adx: current_adx,
      current_di_plus: current_plus,
      current_di_minus: current_minus,
      trend_strength: determine_trend_strength(current_adx)
    }
  end

  @doc """
  Generates a comprehensive trading signal from price data.

  Combines all indicators and produces a unified signal:
  strong_buy, buy, hold, sell, or strong_sell.

  ## Parameters

    * prices - List of closing prices (at least 30 required)
    * highs - List of high prices (optional, for ADX)
    * lows - List of low prices (optional, for ADX)
    * timeframe - Timeframe string for metadata

  ## Examples

      iex> prices = Enum.to_list(1..50)
      iex> highs = Enum.map(prices, & &1 + 1)
      iex> lows = Enum.map(prices, & &1 - 1)
      iex> {:ok, signal} = Analyzer.generate_signal(%{prices: prices, highs: highs, lows: lows})
      iex> Map.get(signal, :signal) in ["strong_buy", "buy", "hold", "sell", "strong_sell"]
      true
  """
  @type signal_input :: %{
          prices: price_list(),
          highs: price_list() | nil,
          lows: price_list() | nil,
          timeframe: String.t() | nil
        }

  @type signal_output :: %{
          signal: String.t(),
          strength: float(),
          details: map()
        }

  @spec generate_signal(signal_input()) :: {:ok, signal_output()} | {:error, String.t()}
  def generate_signal(%{prices: prices} = input) when is_list(prices) and length(prices) >= 30 do
    sma_20 = sma(prices, 20)
    sma_50 = sma(prices, 50)
    current_price = List.last(prices)
    rsi_val = rsi(prices, 14)
    macd_data = macd(prices)
    bb_data = bollinger_bands(prices, 20)

    adx_data =
      case {Map.get(input, :highs), Map.get(input, :lows)} do
        {highs, lows} when is_list(highs) and is_list(lows) and length(highs) >= 15 and length(lows) >= 15 ->
          adx(highs, lows, prices, 14)
        _ ->
          %{
            current_adx: 25.0,
            current_di_plus: 25.0,
            current_di_minus: 25.0,
            trend_strength: "moderate"
          }
      end

    scores = %{
      sma_short: score_sma(current_price, List.last(sma_20)),
      sma_long: score_sma_cross(sma_20, sma_50),
      rsi: score_rsi(rsi_val),
      macd: score_macd(macd_data),
      bollinger: score_bollinger(current_price, bb_data),
      adx: score_adx(adx_data)
    }

    total_score = Enum.sum(Map.values(scores))
    max_possible = 6.0
    normalized_strength = total_score / max_possible
    signal = classify_signal(normalized_strength)

    {:ok,
     %{
       signal: signal,
       strength: abs(normalized_strength),
       details: %{
         scores: scores,
         rsi: rsi_val,
         macd: %{
           current_macd: macd_data.current_macd,
           current_signal: macd_data.current_signal,
           current_histogram: macd_data.current_histogram
         },
         bollinger: %{
           current_price: current_price,
           upper: bb_data.current_upper,
           middle: bb_data.current_middle,
           lower: bb_data.current_lower
         },
         adx: %{
           current_adx: adx_data.current_adx,
           trend_strength: adx_data.trend_strength,
           di_plus: adx_data.current_di_plus,
           di_minus: adx_data.current_di_minus
         },
         sma: %{
           sma_20: List.last(sma_20),
           sma_50: List.last(sma_50),
           current_price: current_price
         },
         timeframe: Map.get(input, :timeframe, "unknown")
       }
     }}
  end

  def generate_signal(%{prices: prices}) when is_list(prices) do
    {:error, "Insufficient data: need at least 30 price points, got #{length(prices)}"}
  end

  def generate_signal(_) do
    {:error, "Invalid input: expected a map with :prices key"}
  end

  # =====================================================================
  # Scoring helpers
  # =====================================================================

  defp score_sma(current_price, sma_value) when is_number(current_price) and is_number(sma_value) do
    cond do
      current_price > sma_value * 1.02 -> 1.0
      current_price > sma_value -> 0.5
      current_price < sma_value * 0.98 -> -1.0
      true -> -0.5
    end
  end

  defp score_sma_cross(sma_short, sma_long) when is_list(sma_short) and is_list(sma_long) do
    case {List.last(sma_short), List.last(sma_long)} do
      {short, long} when short > long -> 1.0
      {short, long} when short < long -> -1.0
      _ -> 0.0
    end
  end

  defp score_rsi(rsi_val) when is_number(rsi_val) do
    cond do
      rsi_val < 30 -> 1.0
      rsi_val < 40 -> 0.5
      rsi_val > 70 -> -1.0
      rsi_val > 60 -> -0.5
      true -> 0.0
    end
  end

  defp score_macd(%{current_histogram: hist}) when is_number(hist) do
    cond do
      hist > 0 -> 0.5
      hist < 0 -> -0.5
      true -> 0.0
    end
  end

  defp score_bollinger(current_price, %{current_lower: lower, current_upper: upper}) do
    cond do
      current_price <= lower -> 1.0
      current_price >= upper -> -1.0
      true -> 0.0
    end
  end

  defp score_adx(%{current_di_plus: di_plus, current_di_minus: di_minus, current_adx: adx}) do
    trend_score =
      cond do
        di_plus > di_minus -> 0.5
        di_minus > di_plus -> -0.5
        true -> 0.0
      end
    strength_factor = min(adx / 50.0, 1.0)
    trend_score * strength_factor
  end

  defp classify_signal(strength) when strength >= 0.5, do: "strong_buy"
  defp classify_signal(strength) when strength >= 0.15, do: "buy"
  defp classify_signal(strength) when strength <= -0.5, do: "strong_sell"
  defp classify_signal(strength) when strength <= -0.15, do: "sell"
  defp classify_signal(_strength), do: "hold"

  defp determine_trend_strength(adx_val) when adx_val >= 50, do: "very_strong"
  defp determine_trend_strength(adx_val) when adx_val >= 40, do: "strong"
  defp determine_trend_strength(adx_val) when adx_val >= 25, do: "moderate"
  defp determine_trend_strength(_adx_val), do: "weak"

  # =====================================================================
  # Internal helpers
  # =====================================================================

  defp price_changes(prices) when length(prices) < 2, do: []

  defp price_changes([first | [second | rest]]) do
    [second - first | price_changes([second | rest])]
  end

  defp sliding_window([], _window), do: []

  defp sliding_window(list, window) do
    if length(list) >= window do
      [Enum.take(list, window) | sliding_window(Enum.drop(list, 1), window)]
    else
      []
    end
  end

  defp sliding_window_prices(prices, 0) do
    Enum.map(prices, fn p -> [p] end)
  end

  defp sliding_window_prices(prices, window) do
    sliding_window(prices, window)
  end

  defp smooth_series(values, period) do
    if length(values) < period, do: values, else: do_smooth(values, period, length(values) - period + 1, [])
  end

  defp do_smooth(_values, _period, 0, acc), do: :lists.reverse(acc)

  defp do_smooth(values, period, remaining, acc) do
    window = Enum.take(values, period)
    avg = Enum.sum(window) / length(window)
    rest = Enum.drop(values, 1)
    do_smooth(rest, period, remaining - 1, [avg | acc])
  end

  defp calculate_true_range(highs, lows, closes) do
    do_true_range(highs, lows, closes, [])
  end

  defp do_true_range([h1 | [h2 | _]], [l1 | [l2 | _]], [c1 | [c2 | _]], acc) do
    tr = max(h1 - l1, abs(h1 - c2), abs(l1 - c2))
    do_true_range([h2 | _], [l2 | _], [c2 | _], [tr | acc])
  end

  defp do_true_range(_highs, _lows, _closes, acc), do: :lists.reverse(acc)

  defp calculate_directional_movement(highs, lows) do
    do_directional_movement(highs, lows, [])
  end

  defp do_directional_movement([h1 | [h2 | _]], [l1 | [l2 | _]], acc) do
    plus_dm =
      case h2 - h1 do
        pd when pd > l1 - l2 and pd > 0 -> pd
        _ -> 0.0
      end
    minus_dm =
      case l1 - l2 do
        md when md > h2 - h1 and md > 0 -> md
        _ -> 0.0
      end
    do_directional_movement([h2 | _], [l2 | _], [%{plus_dm: plus_dm, minus_dm: minus_dm} | acc])
  end

  defp do_directional_movement(_highs, _lows, acc) do
    result = :lists.reverse(acc)
    %{
      plus_dm: Enum.map(result, & &1.plus_dm),
      minus_dm: Enum.map(result, & &1.minus_dm)
    }
  end
end
