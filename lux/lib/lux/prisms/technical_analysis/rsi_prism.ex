defmodule Lux.Prisms.TechnicalAnalysis.RSI do
  @moduledoc """
  A prism that calculates the Relative Strength Index (RSI) for a series of prices.

  RSI is a momentum oscillator that measures the speed and magnitude of recent price changes
  to determine overbought or oversold conditions. Values above 70 indicate overbought,
  below 30 indicate oversold.

  ## Examples

      iex> Lux.Prisms.TechnicalAnalysis.RSI.run(%{
      ...>   prices: [42.0, 43.5, 41.0, 44.0, 45.5, 44.0, 43.0, 46.0, 47.5, 48.0],
      ...>   period: 14
      ...> })
      {:ok, %{rsi: number(), period: 14}}
  """

  use Lux.Prism,
    name: "RSI Indicator",
    description: "Calculates Relative Strength Index (RSI) for price data",
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
          description: "RSI calculation period (default 14)",
          default: 14
        }
      },
      required: ["prices"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        rsi: %{type: :number, description: "Latest RSI value"},
        rsi_series: %{
          type: :array,
          description: "RSI values over time",
          items: %{type: :number}
        },
        period: %{type: :integer},
        signal: %{
          type: :string,
          enum: ["overbought", "oversold", "neutral"],
          description: "Trading signal based on RSI"
        }
      },
      required: ["rsi", "rsi_series", "period", "signal"]
    }

  require Logger

  @default_period 14
  @overbought_threshold 70
  @oversold_threshold 30

  def handler(%{prices: prices} = input, _ctx) when is_list(prices) and length(prices) > 0 do
    period = Map.get(input, :period, @default_period)
    rsi_series = calculate_rsi_series(prices, period)
    latest_rsi = List.last(rsi_series)

    signal =
      cond do
        latest_rsi >= @overbought_threshold -> "overbought"
        latest_rsi <= @oversold_threshold -> "oversold"
        true -> "neutral"
      end

    {:ok, %{
      rsi: Float.round(latest_rsi, 2),
      rsi_series: Enum.map(rsi_series, &Float.round(&1, 2)),
      period: period,
      signal: signal
    }}
  end

  def handler(%{prices: prices}, _ctx) when is_list(prices) and length(prices) == 0 do
    {:error, "prices array must not be empty"}
  end

  def handler(%{prices: _prices}, _ctx) do
    {:error, "invalid input: expected a 'prices' key with a list of numbers"}
  end

  def handler(input, _ctx) do
    {:error, "invalid input: #{inspect(input)}"}
  end

  @doc false
  def calculate_rsi_series(prices, period) when length(prices) <= period do
    [50.0]
  end

  def calculate_rsi_series(prices, period) do
    changes = Enum.zip(Enum.drop(prices, -1), prices) |> Enum.map(fn {prev, curr} -> curr - prev end)

    avg_gain =
      changes
      |> Enum.take(period)
      |> Enum.map(fn c -> if c > 0, do: c, else: 0 end)
      |> Enum.sum()
      |> Kernel./(period)

    avg_loss =
      changes
      |> Enum.take(period)
      |> Enum.map(fn c -> if c < 0, do: abs(c), else: 0 end)
      |> Enum.sum()
      |> Kernel./(period)

    rs = if avg_loss == 0, do: 0, else: avg_gain / avg_loss
    rsi = 100 - (100 / (1 + rs))
    [rsi | tail_rsi(changes, period, avg_gain, avg_loss, Enum.drop(changes, period))]
  end

  defp tail_rsi([], _period, _avg_gain, _avg_loss, _), do: []

  defp tail_rsi([change | rest], period, avg_gain, avg_loss, remaining) do
    gain = if change > 0, do: change, else: 0
    loss = if change < 0, do: abs(change), else: 0

    new_avg_gain = (avg_gain * (period - 1) + gain) / period
    new_avg_loss = (avg_loss * (period - 1) + loss) / period

    rs = if new_avg_loss == 0, do: 0, else: new_avg_gain / new_avg_loss
    rsi = 100 - (100 / (1 + rs))

    [rsi | tail_rsi(rest, period, new_avg_gain, new_avg_loss, remaining)]
  end
end
