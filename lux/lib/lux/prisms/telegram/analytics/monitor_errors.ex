defmodule Lux.Prisms.Telegram.Analytics.MonitorErrors do
  @moduledoc """
  Evaluates Telegram analytics reports against error-rate and latency thresholds.
  """

  use Lux.Prism,
    name: "Monitor Telegram Error Rate",
    description:
      "Raises alert payloads when Telegram bot errors or p95 latency cross configured thresholds",
    input_schema: %{
      type: :object,
      properties: %{
        updates: %{type: :array, description: "Raw Telegram updates or normalized event maps"},
        report: %{type: :object, description: "Optional precomputed analytics report"},
        thresholds: %{
          type: :object,
          description: "Optional threshold overrides for error rate and p95 latency"
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        severity: %{type: :string, enum: ["ok", "warning", "danger"]},
        alerts: %{type: :array},
        errors: %{type: :object},
        performance: %{type: :object}
      },
      required: ["severity", "alerts", "errors", "performance"]
    }

  alias Lux.Integrations.Telegram.Analytics

  @impl true
  def handler(params, _agent) do
    report = fetch_param(params, :report) || Analytics.report(fetch_param(params, :updates) || [])
    thresholds = fetch_param(params, :thresholds) || %{}
    alert_payload = Analytics.alerts(report, thresholds)

    {:ok,
     %{
       severity: alert_payload.severity,
       alerts: alert_payload.alerts,
       thresholds: alert_payload.thresholds,
       errors: report.errors,
       performance: report.performance
     }}
  end

  defp fetch_param(params, key) when is_map(params),
    do:
      if(Map.has_key?(params, key),
        do: Map.get(params, key),
        else: Map.get(params, Atom.to_string(key))
      )
end
