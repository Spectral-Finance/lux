defmodule Lux.Prisms.TechnicalAnalysis.MovingAverage do
  @moduledoc """
  A prism that calculates Simple Moving Average (SMA) and Exponential Moving Average (EMA).

  Moving averages smooth price data to identify trends. SMA gives equal weight to all
  periods; EMA gives more weight to recent prices.

  ## Examples

      iex> Lux.Prisms.TechnicalAnalysis.MovingAverage.run(%{
      ...>   prices: [42.0, 43.5, 41.0, 44.0, 45.5, 44.0, 43.0, 46.0, 47.5, 48.0],
      ...>   type: "sma",
      ...>   period: 5
      ...> })
      {:ok, %{sma: number(), prices: [...], period: 5}}
  """

  use Lux.Prism,
    name: "Moving Average",
    description: "Calculates SMA or EMA for price data",
    input_schema: %{
      type: :object,
      properties: %{
        prices: %{
          type: :array,
          description: "Array of closing prices",
          items: %{type: :number}
        },
        type: %{
          type: :string,
          description: "Type of moving average",
          enum: ["sma", "ema"],
          default: "sma"
        },
        period: %{
          type: :integer,
          description: "Period for the moving average (default 20)",
          default: 20
        }
      },
      required: ["prices"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        ma_value: %{type: :number, description: "Latest moving average value"},
        ma_series: %{type: :array, description: "Moving average values over time"},
        prices: %{type: :array},
        type: %{type: :string},
        period: %{type: :integer},
        trend: %{
          type: :string,
          enum: ["uptrend", "downtrend", "neutral"],
          description: "Trend based on price vs MA"
        }
      },
      required: ["ma_value", "ma_series", "prices", "type", "period", "trend"]
    }

  def handler(%{prices: prices} = input, _ctx) when is_list(prices) and length(prices) > 0 do
    type = Map.get(input, :type, "sma")
    period = Map.get(input, :period, 20)

    ma_series =
      case type do
        "sma" -> calculate_sma_series(prices, period)
        "ema" -> calculate_ema_series(prices, period)
        _ -> calculate_sma_series(prices, period)
      end

    latest_ma = List.last(ma_series)
    latest_price = List.last(prices)

    trend =
      cond do
        latest_price > latest_ma * 1.005 -> "uptrend"
        latest_price < latest_ma * 0.995 -> "downtrend"
        true -> "neutral"
      end

    {:ok, %{
      ma_value: Float.round(latest_ma, 4),
      ma_series: Enum.map(ma_series, &Float.round(&1, 4)),
      prices: prices,
      type: type,
      period: period,
      trend: trend
    }}
  end

  def handler(%{prices: prices}, _ctx) when is_list(prices) do
    {:error, "prices must not be empty"}
  end

  def handler(input, _ctx) do
    {:error, "invalid input: #{inspect(input)}"}
  end

  defp calculate_sma_series(prices, period) do
    if length(prices) < period do
      [Enum.mean(prices)]
    else
      Enum.chunk_every(prices, 1, 1, :discard)
      |> Enum.map(&Enum.mean/1)
      |> Enum.with_index()
      |> Enum.map(fn {mean, idx} ->
        start = max(0, idx - period + 1)
        window = Enum.slice(prices, start..idx)
        Enum.mean(window)
      end)
    end
  end

  defp calculate_ema_series(prices, period) do
    if length(prices) < period do
      [Enum.mean(prices)]
    else
      multiplier = 2 / (period + 1)
      initial = Enum.take(prices, period) |> Enum.mean()

      rest = Enum.drop(prices, period)
      series = [initial | Enum.reduce(rest, [{initial, initial}], fn val, [{_idx, prev} | _] = acc ->
        new_ema = (val - prev) * multiplier + prev
        [{length(acc), new_ema} | acc]
      end) |> Enum.reverse()]

      series
    end
  end
end
