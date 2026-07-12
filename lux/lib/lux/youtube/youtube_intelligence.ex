defmodule Lux.YouTube.YouTubeIntelligence do
  @moduledoc """
  Defines the YouTube Content Intelligence System company.
  """
  use Lux.Company

  company do
    name("YouTube Content Intelligence System")
    mission("Optimize YouTube content and drive channel growth through intelligent analysis")

    has_ceo "Strategy Director" do
      agent(Lux.YouTube.Agents.StrategyAgent)
      goal("Oversee channel strategy, recommend content, and analyze trends")
      can("recommend_content")
      can("analyze_trending_topics")
      can("plan")
      can("approve")
    end

    members do
      has_role "Data Analyst" do
        agent(Lux.YouTube.Agents.AnalyticsAgent)
        goal("Analyze video performance and audience engagement")
        can("analyze_video_performance")
        can("analyze_audience_engagement")
      end

      has_role "Content Optimizer" do
        agent(Lux.YouTube.Agents.OptimizationAgent)
        goal("Optimize content metadata and predict posting times")
        can("optimize_title_thumbnail")
        can("optimize_tags")
        can("generate_description")
        can("predict_posting_time")
      end
    end
  end

  objective :optimize_content_workflow do
    description("Execute a full content optimization workflow for a YouTube video")

    success_criteria(
      "Data analyzed, metadata optimized, and recommendations generated for channel growth."
    )

    steps([
      "Analyze past video performance and audience engagement metrics",
      "Identify trending topics in the channel's niche",
      "Generate optimized title, tags, description, and thumbnail ideas",
      "Determine the optimal posting time",
      "Review and approve final metadata and strategy"
    ])

    input(%{
      required: ["topic", "niche", "video_data"],
      properties: %{
        "topic" => %{type: "string", description: "The topic of the upcoming video"},
        "niche" => %{type: "string", description: "The channel's niche"},
        "video_data" => %{
          type: "array",
          items: %{
            type: "object",
            properties: %{
              "video_id" => %{type: "string"},
              "views" => %{type: "integer"},
              "watch_time_hours" => %{type: "number"},
              "ctr" => %{type: "number"},
              "avg_view_duration" => %{type: "number"}
            }
          },
          description: "Recent video performance data"
        }
      }
    })
  end
end
