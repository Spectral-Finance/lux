defmodule Lux.Prisms.TechnicalAnalysis.MACD do
  @moduledoc """
  A prism that calculates the Moving Average Convergence Divergence (MACD) indicator.

  MACD shows the relationship between two EMAs of prices. The MACD line is the difference
  between the 12-period and 26-period EMA. The signal line is a 9-period EMA of the MACD line.

  ## Examples

      iex> Lux.Prisms.TechnicalAnalysis.MACD.run(%{
      ...>   prices: [42.0, 43.5, 41.0, 44.0, 45.5, 44.0, 43.0, 46.0, 47.5, 48.0]
      ...>     ++ [47.0, 49.0, 50.5, 51.0, 50.0, 52.0, 53.5, 54.0, 53.0, 55.0]
      ...>     ++ [56.0, 55.5, 57.0, 58.5, 59.0, 58.0, 60.0, 61.5, 62.0, 61.0]
      ...>     ++ [63.0, 64.5, 65.0, 64.0, 66.0, 67.5, 68.0, 67.0, 69.0, 70.0],
      ...>   fast_period: 12, slow_period: 26, signal_period: 9
      ...> })
      {:ok, %{macd_line: number(), signal_line: number(), histogram: number()}}
  """

  use Lux.Prism,
    name: "MACD Indicator",
    description: "Calculates Moving Average Convergence Divergence (MACD) indicator",
    input_schema: %{
      type: :object,
      properties: %{
        prices: %{
          type: :array,
          description: "Array of closing prices (at least 30 values recommended)",
          items: %{type: :number}
        },
        fast_period: %{
          type: :integer,
          description: "Fast EMA period (default 12)",
          default: 12
        },
        slow_period: %{
          type: :integer,
          description: "Slow EMA period (default 26)",
          default: 26
        },
        signal_period: %{
          type: :integer,
          description: "Signal line EMA period (default 9)",
          default: 9
        }
      },
      required: ["prices"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        macd_line: %{type: :number, description: "MACD line value"},
        signal_line: %{type: :number, description: "Signal line value"},
        histogram: %{type: :number, description: "MACD histogram (MACD - Signal)"},
        fast_period: %{type: :integer},
        slow_period: %{type: :integer},
        signal_period: %{type: :integer},
        crossover: %{
          type: :string,
          enum: ["bullish", "bearish", "none"],
          description: "Recent crossover signal"
        }
      },
      required: ["macd_line", "signal_line", "histogram", "fast_period", "slow_period", "signal_period", "crossover"]
    }

  def handler(%{prices: prices} = input, _ctx) when is_list(prices) and length(prices) >= 2 do
    fast_period = Map.get(input, :fast_period, 12)
    slow_period = Map.get(input, :slow_period, 26)
    signal_period = Map.get(input, :signal_period, 9)

    ema_slow = compute_ema(prices, slow_period)
    ema_fast = compute_ema(prices, fast_period)
    macd_line = ema_fast - ema_slow

    macd_values = compute_macd_line_series(prices, fast_period, slow_period)
    signal_line = compute_ema(macd_values, signal_period)
    histogram = macd_line - signal_line

    crossover = determine_crossover(macd_values, signal_period, signal_line)

    {:ok, %{
      macd_line: Float.round(macd_line, 4),
      signal_line: Float.round(signal_line, 4),
      histogram: Float.round(histogram, 4),
      fast_period: fast_period,
      slow_period: slow_period,
      signal_period: signal_period,
      crossover: crossover
    }}
  end

  def handler(%{prices: prices}, _ctx) when is_list(prices) do
    {:error, "prices must have at least 2 values for MACD calculation"}
  end

  def handler(input, _ctx) do
    {:error, "invalid input: #{inspect(input)}"}
  end

  defp compute_ema(values, period) when length(values) < period do
    Enum.mean(values)
  end

  defp compute_ema(values, period) do
    multiplier = 2 / (period + 1)
    ema = Enum.take(values, period) |> Enum.mean()

    Enum.drop(values, period)
    |> Enum.reduce(ema, fn val, prev_ema ->
      (val - prev_ema) * multiplier + prev_ema
    end)
  end

  defp compute_macd_line_series(prices, fast_period, slow_period) do
    slow_emas = sliding_ema(prices, slow_period)
    fast_emas = sliding_ema(prices, fast_period)

    min_len = min(length(slow_emas), length(fast_emas))
    Enum.zip(Enum.take(slow_emas, min_len), Enum.take(fast_emas, min_len))
    |> Enum.map(fn {slow, fast} -> fast - slow end)
  end

  defp sliding_ema(prices, period) do
    if length(prices) < period do
      [Enum.mean(prices)]
    else
      multiplier = 2 / (period + 1)
      initial_ema = Enum.take(prices, period) |> Enum.mean()

      rest = Enum.drop(prices, period)
      [initial_ema | Enum.reduce(rest, initial_ema, fn val, prev ->
        ema = (val - prev) * multiplier + prev
        [ema | prev]
      end) |> Enum.reverse()]
    end
  end

  defp determine_crossover(macd_values, signal_period, current_signal) when length(macd_values) < 2 do
    "none"
  end

  defp determine_crossover(macd_values, signal_period, current_signal) do
    prev_macd = Enum.at(macd_values, -2, Enum.at(macd_values, -1))
    curr_macd = List.last(macd_values)

    cond do
      prev_macd <= current_signal and curr_macd > current_signal -> "bullish"
      prev_macd >= current_signal and curr_macd < current_signal -> "bearish"
      true -> "none"
    end
  end
end
