defmodule Lux.Prisms.YouTube.AnalyzeGrowth do
  @moduledoc """
  Prism wrapper for `Lux.Integrations.YouTube.GrowthEngine`.

  Agents can pass imported YouTube analytics exports and receive a deterministic growth
  report without requiring live YouTube credentials.
  """

  use Lux.Prism,
    name: "Analyze YouTube Growth",
    description:
      "Builds analytics, prediction, revenue, retention, ROI, and reporting plans for a YouTube channel",
    input_schema: %{
      type: :object,
      properties: %{
        channel_name: %{type: :string, description: "YouTube channel name"},
        period_days: %{
          type: :integer,
          description: "Number of days covered by the analytics export"
        },
        videos: %{
          type: :array,
          description:
            "Recent video analytics rows with views, impressions, retention, revenue, topics, and audience data"
        },
        competitors: %{type: :array, description: "Competitor benchmark snapshots"},
        goals: %{type: :object, description: "Channel growth and revenue goals"},
        production_cost_usd: %{type: :number, description: "Production spend for ROI tracking"}
      },
      required: ["videos"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        analytics_data_collection: %{
          type: :object,
          description: "Normalized channel and video metrics"
        },
        audience_insights: %{
          type: :object,
          description: "Audience, topic, and traffic-source analysis"
        },
        growth_prediction: %{
          type: :object,
          description: "Projected views, subscribers, and revenue"
        },
        revenue_optimization: %{
          type: :object,
          description: "RPM and monetization recommendations"
        },
        channel_audit: %{
          type: :object,
          description: "Automated channel audit score, findings, and recurring checks"
        },
        automated_report: %{
          type: :object,
          description: "Dashboard-ready report summary and alerts"
        }
      },
      required: [
        "analytics_data_collection",
        "audience_insights",
        "growth_prediction",
        "revenue_optimization",
        "channel_audit",
        "automated_report"
      ]
    }

  alias Lux.Integrations.YouTube.GrowthEngine

  @impl Lux.Prism
  def handler(input, _ctx) do
    GrowthEngine.run(input)
  end
end
