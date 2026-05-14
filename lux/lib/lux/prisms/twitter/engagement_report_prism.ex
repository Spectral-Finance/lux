defmodule Lux.Prisms.Twitter.EngagementReportPrism do
  @moduledoc """
  Builds a Twitter/X engagement analytics report from normalized tweet events.
  """

  use Lux.Prism,
    name: "Twitter Engagement Report",
    description:
      "Aggregates Twitter/X tweet engagement, follower growth, hashtag performance, and sentiment metrics",
    input_schema: %{
      type: :object,
      properties: %{
        tweets: %{type: :array, description: "Normalized tweet records with metrics and hashtags"},
        followers: %{type: :array, description: "Chronological follower count samples"},
        mentions: %{type: :array, description: "Mention records with text for sentiment rollups"},
        thresholds: %{type: :object, description: "Optional alert thresholds"}
      },
      required: ["tweets"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        engagement: %{type: :object},
        follower_growth: %{type: :object},
        hashtags: %{type: :array},
        sentiment: %{type: :object},
        alerts: %{type: :array},
        charts: %{type: :object},
        summary: %{type: :object}
      },
      required: [
        "engagement",
        "follower_growth",
        "hashtags",
        "sentiment",
        "alerts",
        "charts",
        "summary"
      ]
    }

  alias Lux.Integrations.Twitter.Analytics

  def handler(input, _ctx), do: {:ok, Analytics.build_report(input)}
end
