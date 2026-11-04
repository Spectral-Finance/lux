defmodule Lux.YouTube.ContentIntelligence.RecommendationEngineTest do
  use UnitCase, async: true

  alias Lux.YouTube.ContentIntelligence.RecommendationEngine

  describe "happy_path" do
    test "generates recommendations from historical data" do
      input = %{
        historical_videos: [
          %{topic: "cooking", views: 10_000, likes: 500},
          %{topic: "baking", views: 8000, likes: 400},
          %{topic: "desserts", views: 12_000, likes: 600}
        ],
        channel_niche: "cooking"
      }

      {:ok, result} = RecommendationEngine.recommend(input)

      assert is_list(result.recommended_topics)
      assert is_list(result.search_gaps)
      assert length(result.top_performing_topics) == 3
      assert is_list(result.next_video_suggestions)
    end

    test "selects top performing videos" do
      videos = [
        %{topic: "a", views: 100, likes: 10},
        %{topic: "b", views: 1000, likes: 100},
        %{topic: "c", views: 500, likes: 50}
      ]

      result = RecommendationEngine.select_top_performers(videos)
      assert length(result) == 3
      assert hd(result).topic == "b"
    end

    test "discovers search gaps" do
      videos = [%{topic: "cooking", views: 1000}]
      result = RecommendationEngine.discover_search_gaps(videos)
      assert is_list(result)
      assert "how-to" in result
    end

    test "generates topic recommendations" do
      top = [%{topic: "cooking", views: 10_000}]
      result = RecommendationEngine.generate_recommendations(top, "cooking")
      assert length(result) == 1
      assert hd(result).potential_views == 8000
    end
  end

  describe "boundary" do
    test "handles empty historical videos list" do
      input = %{
        historical_videos: [],
        channel_niche: "cooking"
      }

      {:ok, result} = RecommendationEngine.recommend(input)
      assert result.recommended_topics == []
      assert result.top_performing_topics == []
      assert result.next_video_suggestions == []
    end

    test "handles max recommendations limit" do
      input = %{
        historical_videos: [%{topic: "a", views: 100}, %{topic: "b", views: 200}],
        channel_niche: "cooking",
        max_recommendations: 1
      }

      {:ok, result} = RecommendationEngine.recommend(input)
      assert length(result.next_video_suggestions) == 1
    end
  end

  describe "null_input" do
    test "returns error for nil input" do
      assert {:error, :invalid_input} = RecommendationEngine.recommend(nil)
    end

    test "returns error for missing required fields" do
      input = %{historical_videos: []}
      assert {:error, {:missing_fields, _}} = RecommendationEngine.recommend(input)
    end
  end

  describe "empty_input" do
    test "rejects empty map input" do
      assert {:error, {:missing_fields, _}} = RecommendationEngine.recommend(%{})
    end

    test "rejects non-list historical_videos" do
      input = %{historical_videos: "not_a_list", channel_niche: "cooking"}
      assert {:error, {:invalid_value, :historical_videos}} = RecommendationEngine.recommend(input)
    end
  end

  describe "negative" do
    test "rejects non-binary channel_niche" do
      input = %{historical_videos: [], channel_niche: 123}
      assert {:error, {:invalid_value, :channel_niche}} = RecommendationEngine.recommend(input)
    end
  end
end