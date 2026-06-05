defmodule Lux.Prisms.Twitter.GenerateAnalyticsReport do
  @moduledoc """
  Generates a Twitter/X analytics and monitoring report from imported metrics.

  The prism is deliberately credential-free. It expects data already collected by
  a caller, job, export, or future Twitter API transport adapter and returns a
  deterministic report that agents can inspect before any live action.
  """

  use Lux.Prism,
    name: "Generate Twitter Analytics Report",
    description: "Aggregates Twitter/X engagement, sentiment, followers, hashtags, alerts, and report payloads",
    input_schema: %{
      type: :object,
      properties: %{
        account_id: %{type: :string, description: "Twitter/X account identifier for the imported metrics"},
        tweets: %{
          type: :array,
          description: "Imported tweet metrics with impressions and engagement fields"
        },
        mentions: %{
          type: :array,
          description: "Imported mention text and author context for sentiment analysis"
        },
        follower_snapshots: %{
          type: :array,
          description: "Follower count snapshots with timestamp and count fields"
        },
        alert_thresholds: %{
          type: :object,
          description: "Optional alert thresholds such as engagement_rate_below and negative_sentiment_above"
        },
        custom_metrics: %{
          type: :array,
          description: "Custom metric definitions with name, numerator, and denominator fields"
        }
      },
      required: ["tweets"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        account_id: %{type: :string, description: "Account identifier"},
        collection_boundary: %{type: :string, description: "Validation boundary for the report"},
        metrics: %{type: :object, description: "Aggregate engagement metrics"},
        tweet_metrics: %{type: :array, description: "Per-tweet normalized metrics"},
        follower_growth: %{type: :object, description: "Follower growth delta and trend"},
        hashtag_performance: %{type: :array, description: "Hashtag rollups"},
        mention_sentiment: %{type: :object, description: "Mention sentiment summary"},
        custom_metrics: %{type: :array, description: "Evaluated custom metrics"},
        alerts: %{type: :array, description: "Threshold alerts"},
        report_sections: %{type: :object, description: "Human-readable report sections"},
        chart_payloads: %{type: :object, description: "Dashboard-ready chart payloads"},
        quality_notes: %{type: :array, description: "Data quality notes"}
      },
      required: ["account_id", "metrics", "alerts", "quality_notes"]
    }

  alias Lux.Integrations.Twitter.AnalyticsMonitor

  @impl true
  def handler(params, _ctx), do: AnalyticsMonitor.build_report(params)
end
