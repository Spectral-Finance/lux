defmodule Lux.Prisms.Twitter.GenerateAnalyticsReport do
  @moduledoc """
  Prism wrapper for `Lux.Integrations.Twitter.AnalyticsMonitor`.

  Agents can pass Twitter/X metrics from a stream, API client, or export and receive a
  deterministic analytics, monitoring, alerting, and reporting payload.
  """

  use Lux.Prism,
    name: "Generate Twitter Analytics Report",
    description:
      "Builds Twitter/X engagement analytics, monitoring alerts, sentiment, hashtag, follower, and custom reports",
    input_schema: %{
      type: :object,
      properties: %{
        account: %{type: :string, description: "Twitter/X account handle or label"},
        period_days: %{type: :integer, description: "Number of days covered by the metrics"},
        tweets: %{type: :array, description: "Tweet metrics rows"},
        mentions: %{type: :array, description: "Mention rows for sentiment monitoring"},
        follower_snapshots: %{type: :array, description: "Follower count snapshots"},
        thresholds: %{type: :object, description: "Alert thresholds"},
        custom_metrics: %{type: :array, description: "Supported custom metric definitions"}
      },
      required: ["tweets"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        metrics_collection: %{type: :object, description: "Normalized real-time metrics snapshot"},
        data_aggregation: %{type: :object, description: "Aggregated storage and query snapshot"},
        custom_reporting: %{type: :object, description: "Custom report sections and metrics"},
        alert_system: %{type: :object, description: "Threshold alerts and health status"},
        automated_report: %{type: :object, description: "Dashboard-ready analytics report"}
      },
      required: [
        "metrics_collection",
        "data_aggregation",
        "custom_reporting",
        "alert_system",
        "automated_report"
      ]
    }

  alias Lux.Integrations.Twitter.AnalyticsMonitor

  @impl Lux.Prism
  def handler(input, _ctx) do
    AnalyticsMonitor.run(input)
  end
end
