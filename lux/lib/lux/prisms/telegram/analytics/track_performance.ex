defmodule Lux.Prisms.Telegram.Analytics.TrackPerformance do
  @moduledoc """
  A prism for analyzing API latency percentiles, error rates, and detecting threshold breaches.
  """

  use Lux.Prism,
    name: "Track Telegram Bot Performance",
    description: "Evaluates response latency (p50, p95, p99), error rates, and alerts on performance anomalies",
    input_schema: %{
      type: :object,
      properties: %{
        events: %{type: :array, description: "List of collected telemetry events"},
        thresholds: %{type: :object, description: "Optional custom alert thresholds"}
      },
      required: ["events"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        error_rate_percent: %{type: :number},
        latency: %{type: :object},
        alerts: %{type: :array}
      },
      required: ["error_rate_percent", "latency", "alerts"]
    }

  alias Lux.Integrations.Telegram.Analytics.PerformanceMonitor

  def handler(params, _agent) when is_map(params) do
    events = Map.get(params, :events) || Map.get(params, "events", [])
    thresholds = Map.get(params, :thresholds) || Map.get(params, "thresholds", %{})

    result = PerformanceMonitor.analyze(events, thresholds)
    {:ok, result}
  end

  def handler(_, _), do: {:error, "Invalid input: expected events"}
end
