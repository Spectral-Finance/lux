defmodule Lux.Agents.YouTubeAnalytics do
  @moduledoc """
  An agent that analyzes YouTube channel data to provide growth predictions,
  revenue optimization strategies, and automated reporting.
  """

  use Lux.Agent,
    name: "YouTube Analytics & Growth Agent",
    description: "Analyzes YouTube channel performance and provides growth/revenue optimization",
    goal: "Optimize YouTube channel growth, retention, and revenue through data-driven analysis",
    capabilities: [
      :analytics_data_collection,
      :growth_prediction,
      :revenue_optimization,
      :automated_reporting,
      :channel_audit
    ],
    llm_config: %{
      model: "gpt-4o",
      temperature: 0.7,
      json_response: true,
      json_schema: %{
        name: "youtube_analytics_report",
        schema: %{
          type: "object",
          properties: %{
            channel_id: %{
              type: "string",
              description: "The ID of the analyzed channel"
            },
            growth_prediction: %{
              type: "object",
              properties: %{
                projected_subscribers_30d: %{type: "number"},
                projected_views_30d: %{type: "number"},
                trend_analysis: %{type: "string"}
              },
              required: ["projected_subscribers_30d", "projected_views_30d", "trend_analysis"]
            },
            revenue_optimization: %{
              type: "object",
              properties: %{
                estimated_rpm: %{type: "number"},
                suggested_sponsors: %{type: "array", items: %{type: "string"}},
                monetization_tips: %{type: "array", items: %{type: "string"}}
              },
              required: ["estimated_rpm", "suggested_sponsors", "monetization_tips"]
            },
            retention_analysis: %{
              type: "string",
              description: "Analysis of audience retention based on available data"
            },
            benchmarks: %{
              type: "object",
              properties: %{
                views_per_subscriber_ratio: %{type: "number"},
                performance_rating: %{type: "string", enum: ["Poor", "Average", "Good", "Excellent"]}
              },
              required: ["views_per_subscriber_ratio", "performance_rating"]
            },
            action_plan: %{
              type: "array",
              items: %{type: "string"},
              description: "Step-by-step automated report/action plan"
            }
          },
          required: [
            "channel_id",
            "growth_prediction",
            "revenue_optimization",
            "retention_analysis",
            "benchmarks",
            "action_plan"
          ]
        }
      },
      messages: [
        %{
          role: "system",
          content: """
          You are a YouTube Analytics & Growth Agent. You receive channel statistics,
          competitor context, and recent video performance to predict growth, optimize revenue,
          and provide actionable strategies.

          Your output MUST be valid JSON conforming to the youtube_analytics_report schema.
          """
        }
      ]
    }

  require Logger

  @doc """
  Generates a comprehensive analytics report and growth plan based on channel data.
  """
  def generate_report(agent, channel_data) do
    with {:ok, report_json} <-
           send_message(agent, """
           Please analyze the following YouTube channel data and generate a comprehensive
           growth, retention, and revenue optimization report:

           #{Jason.encode!(channel_data, pretty: true)}

           Respond with a complete report including ALL required fields.
           """) do
      {:ok, Jason.decode!(report_json, keys: :atoms)}
    end
  end
end
