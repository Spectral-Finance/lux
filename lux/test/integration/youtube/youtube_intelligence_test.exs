defmodule Lux.Integration.YouTube.YouTubeIntelligenceTest do
  @moduledoc """
  Integration tests showcasing content optimization workflow for YouTube Intelligence System.
  """
  use IntegrationCase, async: true

  alias Lux.Company.Hub.Local
  alias Lux.YouTube.YouTubeIntelligence
  alias Lux.YouTube.Prisms.ContentRecommendationPrism

  @moduletag :integration

  describe "youtube content intelligence workflow" do
    setup do
      # Start a local hub for the company
      hub_name = :"hub_#{:erlang.unique_integer([:positive])}"
      table_name = :"table_#{:erlang.unique_integer([:positive])}"
      start_supervised!({Local, name: hub_name, table_name: table_name})

      # Get the company configuration
      company_config = YouTubeIntelligence.view()

      # Start the company
      {:ok, company_pid} =
        Lux.Company.start_link(YouTubeIntelligence, %{
          name: company_config.name,
          hub: hub_name
        })

      # Register the company with the hub
      {:ok, company_id} = Local.register_company(company_config, hub_name)

      %{company_pid: company_pid, hub: hub_name, company_id: company_id}
    end

    test "youtube agents expose the expected prisms" do
      assert Lux.YouTube.Prisms.PerformanceAnalyticsPrism in
               Lux.YouTube.Agents.AnalyticsAgent.view().prisms

      assert Lux.YouTube.Prisms.MetadataOptimizationPrism in
               Lux.YouTube.Agents.OptimizationAgent.view().prisms

      assert Lux.YouTube.Prisms.ContentRecommendationPrism in
               Lux.YouTube.Agents.StrategyAgent.view().prisms
    end

    test "successfully executes deterministic content optimization pipeline without credentials", %{company_pid: _pid, hub: _hub, company_id: _company_id} do
      # Simulate the workflow deterministically by calling the prisms directly.
      # This proves that raw analytics input is normalized into bounded recommendations and metadata
      # without depending on live OpenAI credentials.

      # 1. Performance Analytics Prism
      {:ok, %{analysis_results: analysis}} = Lux.YouTube.Prisms.PerformanceAnalyticsPrism.run(%{
        "video_data" => [
          %{
            "video_id" => "v1",
            "views" => -500,               # Should be bounded to 0
            "watch_time_hours" => -10.0,   # Should be bounded to 0.0
            "ctr" => 150.0,                # Should be bounded to 100.0
            "avg_view_duration" => 6.5
          }
        ]
      })

      assert length(analysis) == 1
      video_analysis = hd(analysis)
      assert video_analysis.performance_tier == "Excellent"
      assert video_analysis.engagement_metrics.estimated_retention == 65.0
      assert video_analysis.engagement_metrics.audience_loyalty == 0.0

      # 2. Strategy / Content Recommendation Prism
      {:ok, %{recommendations: recs}} = Lux.YouTube.Prisms.ContentRecommendationPrism.run(%{
        "topics" => ["Elixir AI Agents", "Rust Performance"],
        "audience_segments" => ["software engineers", "AI enthusiasts"],
        "channel_metrics" => %{
          "average_ctr" => 150.0, # Will be bounded
          "average_retention" => 65.0
        }
      })

      assert length(recs) == 2
      assert hd(recs).topic == "Elixir AI Agents"

      # 3. Metadata Optimization Prism
      {:ok, %{optimized_titles: titles, optimal_posting_times: times}} = Lux.YouTube.Prisms.MetadataOptimizationPrism.run(%{
        "topic" => "Elixir for AI Agents",
        "target_audience" => "Software Engineering",
        "audience_timezone" => "PST",
        "trend_evidence" => "Monday, Thursday"
      })

      assert length(titles) == 3
      assert length(times) == 2
      assert hd(times) == "Monday peak hours in PST"
    end
  end
end
