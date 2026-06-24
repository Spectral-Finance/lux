defmodule Lux.Agents.TwitterAnalytics do
  @moduledoc """
  An agent that analyzes Twitter metrics and provides engagement reports and alerts.
  """

  use Lux.Agent,
    name: "Twitter Analytics Agent",
    description: "Analyzes Twitter engagement metrics, user growth, and mentions sentiment.",
    goal: "Provide comprehensive Twitter analytics reports and detect engagement anomalies.",
    capabilities: [:twitter_analytics, :sentiment_analysis],
    llm_config: %{
      model: "gpt-4o-mini",
      temperature: 0.5,
      json_response: true,
      json_schema: %{
        name: "twitter_report",
        schema: %{
          type: "object",
          properties: %{
            summary: %{
              type: "string",
              description: "Overall summary of Twitter performance"
            },
            follower_growth_status: %{
              type: "string",
              description: "Assessment of follower growth"
            },
            engagement_rate: %{
              type: "number",
              description: "Calculated engagement rate"
            },
            sentiment_overview: %{
              type: "string",
              description: "Overview of sentiment from recent mentions"
            },
            alerts: %{
              type: "array",
              items: %{type: "string"},
              description: "List of alerts (e.g. dropping engagement, negative sentiment spike)"
            }
          },
          required: [
            "summary",
            "follower_growth_status",
            "engagement_rate",
            "sentiment_overview",
            "alerts"
          ]
        }
      },
      messages: [
        %{
          role: "system",
          content: """
          You are a Twitter Analytics Agent. Your role is to analyze Twitter metrics (tweet engagement, follower count, sentiment analysis of mentions) and generate a comprehensive report.

          Identify any alerts such as abnormally low engagement or highly negative sentiment.
          """
        }
      ]
    }

  require Logger

  def generate_report(agent, metrics_data) do
    with {:ok, report} <-
           send_message(agent, """
           Please analyze the following Twitter metrics data and generate a report:
           #{Jason.encode!(metrics_data, pretty: true)}

           Respond with a complete report including ALL required fields in the JSON schema.
           """) do
      {:ok, Jason.decode!(report, keys: :atoms)}
    end
  end
end
