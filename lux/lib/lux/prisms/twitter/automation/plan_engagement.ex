defmodule Lux.Prisms.Twitter.Automation.PlanEngagement do
  @moduledoc """
  Plans Twitter/X automation work for content scheduling, rule-based engagement,
  and queue management without performing network side effects.
  """

  use Lux.Prism,
    name: "Plan Twitter Automation Engagement",
    description:
      "Creates an auditable Twitter/X automation plan with scheduled posts, engagement actions, and rate-limited queue entries.",
    input_schema: %{
      type: :object,
      properties: %{
        now: %{
          type: :string,
          description: "Optional ISO8601 datetime used as the planning reference"
        },
        content_calendar: %{
          type: :array,
          description: "Post drafts to schedule and validate",
          items: %{type: :object}
        },
        mentions: %{
          type: :array,
          description: "Incoming mentions, replies, or audience signals to evaluate",
          items: %{type: :object}
        },
        rules: %{
          type: :array,
          description: "Engagement rules such as auto_reply, engage_keyword, or follow_candidate",
          items: %{type: :object}
        },
        queue_policy: %{
          type: :object,
          description: "Rate limits, spacing, quiet hours, and duplicate-window settings"
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        scheduled_posts: %{
          type: :array,
          description: "Validated post schedule entries",
          items: %{type: :object}
        },
        engagement_actions: %{
          type: :array,
          description: "Rule-generated engagement actions with safety status",
          items: %{type: :object}
        },
        queue: %{
          type: :array,
          description: "Rate-limited execution queue",
          items: %{type: :object}
        },
        content_calendar: %{
          type: :array,
          description: "Calendar view of scheduled and rejected content",
          items: %{type: :object}
        },
        moderation: %{
          type: :array,
          description: "Rejected content and actions requiring review",
          items: %{type: :object}
        },
        performance: %{
          type: :object,
          description: "Queue depth, moderation counts, and hourly bucket metrics"
        }
      },
      required: [
        "scheduled_posts",
        "engagement_actions",
        "queue",
        "content_calendar",
        "moderation",
        "performance"
      ]
    }

  alias Lux.Integrations.Twitter.AutomationEngine

  @doc """
  Returns a Twitter/X automation plan for an agent to review or execute later.
  """
  def handler(params, _agent), do: AutomationEngine.plan(params)
end
