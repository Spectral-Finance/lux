defmodule Lux.Prisms.YouTube.ManageCommunity do
  @moduledoc """
  Prism wrapper for YouTube community management planning.
  """

  use Lux.Prism,
    name: "YouTube Community Manager",
    description:
      "Builds offline YouTube comment, moderation, response, scheduling, and campaign plans",
    input_schema: %{
      type: :object,
      properties: %{
        channel: %{type: :string, description: "Channel name"},
        comments: %{type: :array, description: "Imported YouTube comments"},
        subscriber_events: %{type: :array, description: "Subscriber interaction events"},
        campaigns: %{type: :array, description: "Engagement campaign briefs"},
        goals: %{type: :array, description: "Community goals"},
        content_topics: %{type: :array, description: "Planned community post topics"},
        platforms: %{type: :array, description: "Promotion platforms"}
      },
      required: ["comments"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        comment_management: %{type: :object, description: "Comment analysis and response queues"},
        automated_response_generation: %{
          type: :object,
          description: "Response templates and generated replies"
        },
        sentiment_analysis: %{type: :object, description: "Sentiment distribution and alerts"},
        moderation_system: %{type: :object, description: "Moderation queue and policy"},
        community_post_schedule: %{type: :object, description: "Scheduled community posts"},
        subscriber_interaction_patterns: %{
          type: :object,
          description: "Subscriber source and segment patterns"
        },
        cross_platform_promotion: %{type: :array, description: "Platform-specific promotion plan"},
        engagement_campaign_management: %{
          type: :array,
          description: "Campaign progress and actions"
        },
        fan_interaction_automation: %{
          type: :object,
          description: "Automation rules and queue sizes"
        }
      },
      required: [
        "comment_management",
        "automated_response_generation",
        "sentiment_analysis",
        "moderation_system"
      ]
    }

  alias Lux.Integrations.YouTube.CommunityManager

  def handler(input, _ctx), do: CommunityManager.run(input)
end
