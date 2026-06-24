defmodule Lux.Integration.Agent.YouTubeAnalyticsTest do
  use IntegrationCase, async: true

  alias Lux.Agents.YouTubeAnalytics

  @seed 42

  describe "youtube analytics agent" do
    setup do
      config = %{
        api_key: Application.get_env(:lux, :api_keys)[:integration_openai],
        model: Application.get_env(:lux, :open_ai_models)[:cheapest],
        temperature: 0.0,
        seed: @seed,
        receive_timeout: 30_000
      }

      {:ok, pid} =
        YouTubeAnalytics.start_link(%{
          llm_config: config
        })

      {:ok, pid: pid}
    end

    test "generates a comprehensive youtube analytics report", %{pid: pid} do
      channel_data = %{
        channel_id: "UC1234567890",
        title: "Test Tech Channel",
        description: "A channel about technology and coding.",
        subscriber_count: 500_000,
        video_count: 120,
        view_count: 25_000_000,
        recent_videos_performance: [
          %{title: "How to code in Elixir", views: 150_000, comments: 400},
          %{title: "My dev setup", views: 300_000, comments: 1200}
        ]
      }

      {:ok, report} = YouTubeAnalytics.generate_report(pid, channel_data)

      assert is_map(report)
      assert report.channel_id == "UC1234567890"
      
      # Growth prediction
      assert Map.has_key?(report, :growth_prediction)
      assert Map.has_key?(report.growth_prediction, :projected_subscribers_30d)
      assert is_number(report.growth_prediction.projected_subscribers_30d)

      # Revenue optimization
      assert Map.has_key?(report, :revenue_optimization)
      assert Map.has_key?(report.revenue_optimization, :estimated_rpm)
      assert is_number(report.revenue_optimization.estimated_rpm)
      assert is_list(report.revenue_optimization.suggested_sponsors)

      # Retention and Benchmarks
      assert Map.has_key?(report, :retention_analysis)
      assert Map.has_key?(report, :benchmarks)
      assert report.benchmarks.performance_rating in ["Poor", "Average", "Good", "Excellent"]
      
      # Action plan
      assert is_list(report.action_plan)
      assert length(report.action_plan) > 0
    end
  end
end
