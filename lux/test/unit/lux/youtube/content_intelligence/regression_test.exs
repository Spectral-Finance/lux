defmodule Lux.YouTube.ContentIntelligence.RegressionTest do
  use UnitCase, async: true

  alias Lux.YouTube.ContentIntelligence
  alias Lux.Prisms.YouTubeContentIntelligencePrism

  describe "regression" do
    test "defect: analyze_video processes all optional fields without crashing" do
      video_data = %{
        views: 50_000,
        watch_time_minutes: 25_000,
        video_length_seconds: 1200,
        likes: 2500,
        dislikes: 5,
        comments: 250,
        shares: 100,
        published_at: ~U[2024-01-01 12:00:00Z],
        current_time: ~U[2024-01-08 12:00:00Z],
        subscribers: 50_000,
        non_subscriber_watch_time: 10_000,
        subscriber_watch_time: 15_000,
        traffic_sources: %{"browse" => 20_000, "search" => 15_000, "suggested" => 15_000},
        title: "Ultimate Guide to YouTube Growth",
        video_topic: "YouTube Growth",
        video_description: "Complete guide to growing your YouTube channel",
        chapters: [%{start_time: 0, title: "Intro"}, %{start_time: 300, title: "Tips"}],
        keywords: ["youtube", "growth", "tutorial", "tips"],
        historical_videos: [%{topic: "youtube", views: 30_000}, %{topic: "growth", views: 20_000}],
        historical_performance: [%{hour: 18, day_of_week: 1, views: 5000}, %{hour: 19, day_of_week: 1, views: 7000}],
        search_queries: ["youtube growth", "channel tips"],
        trending_data: %{"youtube growth" => 75, "channel tips" => 45},
        channel_niche: "youtube"
      }

      {:ok, result} = ContentIntelligence.analyze_video(video_data)

      assert result.performance.view_velocity_per_hour > 0
      assert result.engagement.loyalty_score >= 0
      assert Map.has_key?(result, :recommendations)
      assert is_list(result.recommendations.top_performing_topics)
      assert result.posting_times.peak_viewer_activity != []
      assert result.title_optimization.ctr_score >= 0
      assert result.metadata.tags_within_limit == true
      assert result.trending_topics.saturation_index >= 0
    end

    test "defect: prism handles all actions correctly" do
      video_data = %{
        views: 50_000,
        watch_time_minutes: 25_000,
        video_length_seconds: 1200,
        likes: 2500,
        dislikes: 5,
        comments: 250,
        shares: 100,
        published_at: ~U[2024-01-01 12:00:00Z],
        current_time: ~U[2024-01-08 12:00:00Z],
        timezone: "UTC",
        subscribers: 50_000,
        non_subscriber_watch_time: 10_000,
        subscriber_watch_time: 15_000,
        traffic_sources: %{"browse" => 20_000, "search" => 15_000, "suggested" => 15_000},
        title: "Ultimate Guide to YouTube Growth",
        video_topic: "YouTube Growth",
        video_description: "Complete guide to growing your YouTube channel",
        chapters: [%{start_time: 0, title: "Intro"}, %{start_time: 300, title: "Tips"}],
        keywords: ["youtube", "growth", "tutorial", "tips"],
        historical_videos: [%{topic: "youtube", views: 30_000}, %{topic: "growth", views: 20_000}],
        historical_performance: [%{hour: 18, day_of_week: 1, views: 5000}, %{hour: 19, day_of_week: 1, views: 7000}],
        search_queries: ["youtube growth", "channel tips"],
        trending_data: %{"youtube growth" => 75, "channel tips" => 45},
        channel_niche: "youtube"
      }

      # Test each action through the prism
      actions = [
        "analyze_video", "performance", "engagement", "recommendations",
        "posting_times", "title_thumbnail", "metadata", "trending_topics"
      ]

      Enum.each(actions, fn action ->
        input = %{"action" => action, "video_data" => video_data}
        result = YouTubeContentIntelligencePrism.run(input, nil)
        assert {:ok, _} = result
      end)
    end

    test "defect: performance analytics handles missing engagement fields gracefully" do
      input = %{
        views: 1000,
        watch_time_minutes: 500,
        video_length_seconds: 600,
        published_at: ~U[2024-01-01 12:00:00Z],
        current_time: ~U[2024-01-02 12:00:00Z]
      }

      {:ok, result} = ContentIntelligence.performance(input)
      assert result.engagement_rate == 0.0
    end

    test "defect: prism returns modules list" do
      input = %{"action" => "modules"}
      {:ok, result} = YouTubeContentIntelligencePrism.run(input, nil)
      assert is_list(result["result"])
      assert length(result["result"]) == 7
    end
  end
end