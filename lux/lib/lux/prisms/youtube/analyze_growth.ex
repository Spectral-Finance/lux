defmodule Lux.Prisms.YouTube.AnalyzeGrowth do
  @moduledoc """
  Prism wrapper around `Lux.Integrations.YouTube.AnalyticsGrowth`.

  It lets agents submit normalized channel snapshots and competitor snapshots,
  then receive a deterministic growth report with trend, forecast, audit,
  benchmark, revenue optimization, and prioritized recommendations.
  """

  use Lux.Prism,
    name: "YouTube Growth Analysis",
    description: "Analyzes YouTube channel growth, retention, revenue, benchmarks, and forecasts",
    input_schema: %{
      type: :object,
      properties: %{
        channel_series: %{
          type: :array,
          description: "Ordered list of normalized channel metric snapshots"
        },
        competitors: %{
          type: :array,
          description: "Optional competitor metric snapshots for benchmarking"
        },
        forecast_periods: %{
          type: :integer,
          description: "Number of future periods to forecast"
        },
        target_rpm: %{
          type: :number,
          description: "Target revenue per thousand views for optimization"
        }
      },
      required: ["channel_series"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        summary: %{type: :object},
        trend: %{type: :object},
        forecast: %{type: :array},
        audit: %{type: :object},
        benchmark: %{type: :object},
        revenue_optimization: %{type: :object},
        recommendations: %{type: :array}
      },
      required: ["summary", "trend", "forecast", "audit", "benchmark", "revenue_optimization"]
    }

  alias Lux.Integrations.YouTube.AnalyticsGrowth

  def handler(%{channel_series: channel_series} = input, _ctx) when is_list(channel_series) do
    competitors = Map.get(input, :competitors, [])

    opts =
      input
      |> Map.take([:forecast_periods, :target_rpm, :target_subscriber_conversion_rate])
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Enum.into([])

    {:ok, AnalyticsGrowth.report(channel_series, competitors, opts)}
  end

  def handler(%{"channel_series" => channel_series} = input, ctx) when is_list(channel_series) do
    atomized = %{
      channel_series: channel_series,
      competitors: Map.get(input, "competitors", []),
      forecast_periods: Map.get(input, "forecast_periods", 3),
      target_rpm: Map.get(input, "target_rpm"),
      target_subscriber_conversion_rate: Map.get(input, "target_subscriber_conversion_rate")
    }

    handler(atomized, ctx)
  end

  def handler(_input, _ctx), do: {:error, "channel_series must be a list of metric snapshots"}
end
