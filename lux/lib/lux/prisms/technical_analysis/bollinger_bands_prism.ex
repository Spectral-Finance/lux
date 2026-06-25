defmodule Lux.Prisms.TechnicalAnalysis.BollingerBands do
  @moduledoc """
  A prism that calculates Bollinger Bands for price data.

  Bollinger Bands consist of a middle SMA and two bands at a specified distance
  (usually 2 standard deviations) from the SMA. Price near the upper band suggests
  overbought; near lower band suggests oversold.

  ## Examples

      iex> Lux.Prisms.TechnicalAnalysis.BollingerBands.run(%{
      ...>   prices: [42.0, 43.5, 41.0, 44.0, 45.5, 44.0, 43.0, 46.0, 47.5, 48.0]
      ...>     ++ [47.0, 49.0, 50.5, 51.0, 50.0, 52.0, 53.5, 54.0, 53.0, 55.0],
      ...>   period: 20, std_dev: 2
      ...> })
      {:ok, %{upper_band: number(), middle_band: number(), lower_band: number(), bandwidth: number()}}
  """

  use Lux.Prism,
    name: "Bollinger Bands",
    description: "Calculates Bollinger Bands for price data",
    input_schema: %{
      type: :object,
      properties: %{
        prices: %{
          type: :array,
          description: "Array of closing prices",
          items: %{type: :number}
        },
        period: %{
          type: :integer,
          description: "SMA period (default 20)",
          default: 20
        },
        std_dev: %{
          type: :number,
          description: "Standard deviation multiplier (default 2)",
          default: 2
        }
      },
      required: ["prices"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        upper_band: %{type: :number},
        middle_band: %{type: :number},
        lower_band: %{type: :number},
        bandwidth: %{type: :number, description: "(Upper - Lower) / Middle * 100"},
        pct_b: %{
          type: :number,
          description: "Position within bands: >1 above upper, <0 below lower"
        },
        period: %{type: :integer},
        signal: %{
          type: :string,
          enum: ["above_upper", "below_lower", "near_middle", "within_bands"],
          description: "Price position signal"
        }
      },
      required: ["upper_band", "middle_band", "lower_band", "bandwidth", "pct_b", "period", "signal"]
    }

  def handler(%{prices: prices} = input, _ctx) when is_list(prices) and length(prices) > 0 do
    period = Map.get(input, :period, 20)
    std_dev_mult = Map.get(input, :std_dev, 2)

    window = Enum.take(prices, min(period, length(prices)))
    middle = Enum.mean(window)
    stddev = calculate_stddev(window, middle)

    upper = middle + std_dev_mult * stddev
    lower = middle - std_dev_mult * stddev
    bandwidth = if middle != 0, do: (upper - lower) / abs(middle) * 100, else: 0
    latest_price = List.last(prices)
    pct_b = if upper != lower, do: (latest_price - lower) / (upper - lower), else: 0.5

    signal =
      cond do
        pct_b > 1 -> "above_upper"
        pct_b < 0 -> "below_lower"
        abs(pct_b - 0.5) < 0.1 -> "near_middle"
        true -> "within_bands"
      end

    {:ok, %{
      upper_band: Float.round(upper, 4),
      middle_band: Float.round(middle, 4),
      lower_band: Float.round(lower, 4),
      bandwidth: Float.round(bandwidth, 4),
      pct_b: Float.round(pct_b, 4),
      period: period,
      signal: signal
    }}
  end

  def handler(%{prices: prices}, _ctx) when is_list(prices) do
    {:error, "prices must not be empty"}
  end

  def handler(input, _ctx) do
    {:error, "invalid input: #{inspect(input)}"}
  end

  defp calculate_stddev(values, mean) do
    variance =
      Enum.reduce(values, 0, fn v, acc ->
        acc + (v - mean) ** 2
      end) / length(values)

    :math.sqrt(variance)
  end

  defp min(a, b) when a < b, do: a
  defp min(_a, b), do: b
end
