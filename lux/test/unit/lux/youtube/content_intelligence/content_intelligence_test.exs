defmodule Lux.YouTube.ContentIntelligenceTest do
  use UnitCase, async: true

  alias Lux.YouTube.ContentIntelligence

  describe "happy_path" do
    test "runs holistic video analysis" do
      video_data = %{
        views: 10_000,
        watch_time_minutes: 5000,
        video_length_seconds: 600,
        likes: 500,
        comments: 50,
        shares: 25,
        published_at: ~U[2024-01-01 12:00:00Z],
        current_time: ~U[2024-01-02 12:00:00Z],
        subscribers: 10_000,
        non_subscriber_watch_time: 3000,
        subscriber_watch_time: 7000,
        traffic_sources: %{"browse" => 5000},
        title: "10 Cooking Tips",
        video_topic: "Cooking",
        video_description: "Learn to cook",
        historical_videos: [%{topic: "cooking", views: 5000}],
        historical_performance: [%{hour: 18, day_of_week: 1, views: 5000}],
        search_queries: ["cooking"],
        trending_data: %{"cooking" => 80},
        channel_niche: "cooking"
      }

      {:ok, result} = ContentIntelligence.analyze_video(video_data)

      assert Map.has_key?(result, :performance)
      assert Map.has_key?(result, :engagement)
      assert Map.has_key?(result, :recommendations)
      assert Map.has_key?(result, :posting_times)
      assert Map.has_key?(result, :title_optimization)
      assert Map.has_key?(result, :metadata)
      assert Map.has_key?(result, :trending_topics)
    end

    test "analyzes performance only" do
      input = %{
        views: 1000,
        watch_time_minutes: 500,
        video_length_seconds: 600,
        published_at: ~U[2024-01-01 12:00:00Z],
        current_time: ~U[2024-01-02 12:00:00Z],
        likes: 0,
        comments: 0,
        shares: 0
      }

      {:ok, result} = ContentIntelligence.performance(input)
      assert result.view_velocity_per_hour > 0
    end

    test "analyzes engagement only" do
      input = %{
        subscribers: 1000,
        non_subscriber_watch_time: 1000,
        subscriber_watch_time: 2000,
        traffic_sources: %{"browse" => 3000},
        likes: 100,
        dislikes: 0,
        comments: 10,
        views: 5000
      }

      {:ok, result} = ContentIntelligence.engagement(input)
      assert result.loyalty_score >= 0
    end

    test "generates recommendations" do
      input = %{
        historical_videos: [%{topic: "a", views: 100}],
        channel_niche: "cooking"
      }

      {:ok, result} = ContentIntelligence.recommendations(input)
      assert is_list(result.recommended_topics)
    end

    test "predicts posting times" do
      input = %{
        historical_performance: [%{hour: 18, day_of_week: 1, views: 5000}],
        timezone: "UTC"
      }

      {:ok, result} = ContentIntelligence.posting_times(input)
      assert is_list(result.peak_viewer_activity)
    end

    test "optimizes title and thumbnail" do
      input = %{title: "My Video Title"}
      {:ok, result} = ContentIntelligence.title_thumbnail(input)
      assert result.ctr_score >= 0
    end

    test "generates metadata" do
      input = %{video_topic: "Test", video_description: "Test desc"}
      {:ok, result} = ContentIntelligence.metadata(input)
      assert is_binary(result.seo_description)
    end

    test "analyzes trending topics" do
      input = %{
        search_queries: ["test"],
        trending_data: %{"test" => 50},
        channel_niche: "cooking"
      }

      {:ok, result} = ContentIntelligence.trending_topics(input)
      assert is_list(result.search_momentum)
    end

    test "returns modules list" do
      result = ContentIntelligence.modules()
      assert is_list(result)
      assert length(result) == 7
    end
  end

  describe "boundary" do
    test "handles minimal video data for analysis" do
      input = %{
        views: 0,
        watch_time_minutes: 0,
        video_length_seconds: 1,
        published_at: ~U[2024-01-01 12:00:00Z],
        current_time: ~U[2024-01-01 12:00:00Z],
        likes: 0,
        comments: 0,
        shares: 0
      }

      {:ok, result} = ContentIntelligence.analyze_video(input)
      assert Map.has_key?(result, :performance)
      assert Map.has_key?(result, :engagement)
    end

    test "handles analysis with optional data missing" do
      input = %{
        views: 100,
        watch_time_minutes: 50,
        video_length_seconds: 600,
        published_at: ~U[2024-01-01 12:00:00Z],
        current_time: ~U[2024-01-02 12:00:00Z],
        likes: 0,
        comments: 0,
        shares: 0
      }

      {:ok, result} = ContentIntelligence.analyze_video(input)
      assert not Map.has_key?(result, :recommendations)
      assert not Map.has_key?(result, :posting_times)
    end
  end

  describe "null_input" do
    test "returns error for nil input" do
      assert {:error, :invalid_input} = ContentIntelligence.analyze_video(nil)
    end

    test "returns error for non-map input" do
      assert {:error, :invalid_input} = ContentIntelligence.analyze_video("not_a_map")
    end

    test "performance rejects nil input" do
      assert {:error, :invalid_input} = ContentIntelligence.performance(nil)
    end

    test "engagement rejects nil input" do
      assert {:error, :invalid_input} = ContentIntelligence.engagement(nil)
    end
  end

  describe "empty_input" do
    test "handles empty-ish map input for analyze_video" do
      input = %{
        views: 0,
        watch_time_minutes: 0,
        video_length_seconds: 1,
        published_at: ~U[2024-01-01 12:00:00Z],
        current_time: ~U[2024-01-01 12:00:00Z],
        likes: 0,
        comments: 0,
        shares: 0
      }
      {:ok, _} = ContentIntelligence.analyze_video(input)
    end

    test "performance rejects empty map" do
      assert {:error, {:missing_fields, _}} = ContentIntelligence.performance(%{})
    end
  end

  describe "negative" do
    test "performance rejects invalid input type" do
      assert {:error, :invalid_input} = ContentIntelligence.performance(123)
    end

    test "engagement rejects invalid input type" do
      assert {:error, :invalid_input} = ContentIntelligence.engagement(123)
    end
  end

  describe "regression" do
    test "defect: full pipeline processes video without crashing" do
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
      assert result.metadata.tags_character_count < 495
      assert result.title_optimization.character_count == String.length("Ultimate Guide to YouTube Growth")
    end

    test "prism processes analyze_video action" do
      alias Lux.Prisms.YouTubeContentIntelligencePrism

      input = %{
        "action" => "analyze_video",
        "video_data" => %{
          views: 1000,
          watch_time_minutes: 500,
          video_length_seconds: 600,
          published_at: ~U[2024-01-01 12:00:00Z],
          current_time: ~U[2024-01-02 12:00:00Z],
          likes: 0,
          comments: 0,
          shares: 0
        }
      }

      {:ok, result} = YouTubeContentIntelligencePrism.run(input, nil)
      assert result["action"] == "analyze_video"
      assert Map.has_key?(result["result"], :performance)
    end

    test "prism returns modules list" do
      alias Lux.Prisms.YouTubeContentIntelligencePrism

      input = %{"action" => "modules"}
      {:ok, result} = YouTubeContentIntelligencePrism.run(input, nil)
      assert result["action"] == "modules"
      assert is_list(result["result"])
    end

    test "prism rejects missing action" do
      alias Lux.Prisms.YouTubeContentIntelligencePrism

      input = %{"video_data" => %{}}
      assert {:error, {:missing_field, "action"}} = YouTubeContentIntelligencePrism.run(input, nil)
    end

    test "prism rejects unknown action" do
      alias Lux.Prisms.YouTubeContentIntelligencePrism

      input = %{"action" => "invalid_action", "video_data" => %{}}
      assert {:error, {:unknown_action, "invalid_action"}} = YouTubeContentIntelligencePrism.run(input, nil)
    end
  end
end