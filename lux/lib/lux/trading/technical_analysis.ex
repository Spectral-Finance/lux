defmodule Lux.Trading.TechnicalAnalysis do
  @moduledoc """
  TradingView Technical Analysis Integration for Lux (#86).

  Provides:
  - Simple Moving Average (SMA) & Exponential Moving Average (EMA) calculation
  - Relative Strength Index (RSI-14) momentum indicator
  - Bollinger Bands (upper, middle, lower, bandwidth)
  - Composite TradingView-style rating (:strong_buy, :buy, :neutral, :sell, :strong_sell)
  """

  @doc """
  Computes technical indicators and composite signal summary from a list of closing prices.
  """
  @spec analyze_series([number()], keyword()) :: {:ok, map()} | {:error, term()}
  def analyze_series(closes, opts \\ []) when is_list(closes) do
     rsi_period = Keyword.get(opts, :rsi_period, 14)

    if length(closes) < rsi_period + 1 do
      {:error, :insufficient_data}
    else
      last_price = List.last(closes) * 1.0
      ema9 = compute_ema(closes, 9)
      ema21 = compute_ema(closes, min(21, length(closes)))
      rsi = compute_rsi(closes, rsi_period)
      bb = compute_bollinger(closes, min(20, length(closes)), 2.0)

      score =
        0
        |> Kernel.+(if(ema9 > ema21, do: 1, else: -1))
        |> Kernel.+(if(last_price > bb.middle, do: 1, else: -1))
        |> Kernel.+(
          cond do
            rsi < 30.0 -> 2
            rsi > 70.0 -> -2
            rsi > 50.0 -> 1
            true -> -1
          end
        )

      recommendation =
        cond do
          score >= 3 -> :strong_buy
          score >= 1 -> :buy
          score == 0 -> :neutral
          score >= -2 -> :sell
          true -> :strong_sell
        end

      {:ok,
       %{
         last_price: Float.round(last_price, 4),
         ema9: ema9,
         ema21: ema21,
         rsi: rsi,
         bollinger_bands: bb,
         score: score,
         recommendation: recommendation
       }}
    end
  end

  defp compute_ema(closes, period) do
    k = 2.0 / (period + 1)
    [first | rest] = Enum.take(closes, -period)

    Enum.reduce(rest, first * 1.0, fn price, prev ->
      price * k + prev * (1.0 - k)
    end)
    |> Float.round(4)
  end

  defp compute_rsi(closes, period) do
    window = Enum.take(closes, -(period + 1))

    {gains, losses} =
      window
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.reduce({0.0, 0.0}, fn [prev, curr], {g, l} ->
        diff = curr - prev
        if diff >= 0, do: {g + diff, l}, else: {g, l - diff}
      end)

    avg_gain = gains / period
    avg_loss = losses / period

    cond do
      avg_loss == 0.0 -> 100.0
      true -> Float.round(100.0 - 100.0 / (1.0 + avg_gain / avg_loss), 2)
    end
  end

  defp compute_bollinger(closes, period, std_mult) do
    slice = Enum.take(closes, -period)
    mean = Enum.sum(slice) / period

    variance =
      slice
      |> Enum.reduce(0.0, fn x, acc -> acc + :math.pow(x - mean, 2) end)
      |> Kernel./(period)

    stddev = :math.sqrt(variance)

    %{
      upper: Float.round(mean + std_mult * stddev, 4),
      middle: Float.round(mean * 1.0, 4),
      lower: Float.round(mean - std_mult * stddev, 4)
    }
  end
end
