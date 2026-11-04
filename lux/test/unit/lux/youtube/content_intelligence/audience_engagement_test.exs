defmodule Lux.YouTube.ContentIntelligence.AudienceEngagementTest do
  use UnitCase, async: true

  alias Lux.YouTube.ContentIntelligence.AudienceEngagement

  describe "happy_path" do
    test "analyzes audience engagement with valid data" do
      input = %{
        subscribers: 10_000,
        non_subscriber_watch_time: 3000,
        subscriber_watch_time: 7000,
        traffic_sources: %{"browse" => 5000, "search" => 3000, "suggested" => 2000},
        likes: 500,
        dislikes: 10,
        comments: 50,
        views: 10_000
      }

      {:ok, result} = AudienceEngagement.analyze(input)

      assert result.loyalty_score >= 0
      assert result.loyalty_score <= 100
      assert result.subscriber_vs_non_subscriber_ratio.subscriber >= 0
      assert result.subscriber_vs_non_subscriber_ratio.non_subscriber >= 0
      assert is_list(result.traffic_source_classification)
      assert result.engagement_grade in ["A", "B", "C", "D", "F"]
    end

    test "calculates loyalty score correctly" do
      result = AudienceEngagement.loyalty_score(7000, 10_000)
      assert result == 70
    end

    test "returns zero loyalty for zero total watch time" do
      result = AudienceEngagement.loyalty_score(0, 0)
      assert result == 0
    end

    test "calculates subscriber ratio correctly" do
      result = AudienceEngagement.subscriber_ratio(7000, 3000)
      assert result.subscriber == 70
      assert result.non_subscriber == 30
    end

    test "classifies traffic sources by dominance" do
      sources = %{"browse" => 5000, "search" => 3000, "suggested" => 2000}
      result = AudienceEngagement.classify_traffic_sources(sources)
      assert length(result) == 3
      assert hd(result).source == "browse"
      assert hd(result).percentage == 50
    end

    test "calculates engagement grade correctly" do
      assert AudienceEngagement.engagement_grade(12.0) == "A"
      assert AudienceEngagement.engagement_grade(8.0) == "B"
      assert AudienceEngagement.engagement_grade(6.0) == "C"
      assert AudienceEngagement.engagement_grade(4.0) == "D"
      assert AudienceEngagement.engagement_grade(1.0) == "F"
    end
  end

  describe "boundary" do
    test "handles zero subscribers and views" do
      input = %{
        subscribers: 0,
        non_subscriber_watch_time: 0,
        subscriber_watch_time: 0,
        traffic_sources: %{"browse" => 0},
        likes: 0,
        dislikes: 0,
        comments: 0,
        views: 0
      }

      {:ok, result} = AudienceEngagement.analyze(input)
      assert result.loyalty_score == 0
      assert result.engagement_rate == 0.0
    end

    test "handles 100% subscriber watch time" do
      input = %{
        subscribers: 5000,
        non_subscriber_watch_time: 0,
        subscriber_watch_time: 10_000,
        traffic_sources: %{"browse" => 10_000},
        likes: 1000,
        dislikes: 0,
        comments: 100,
        views: 10_000
      }

      {:ok, result} = AudienceEngagement.analyze(input)
      assert result.loyalty_score == 100
    end
  end

  describe "null_input" do
    test "returns error for nil input" do
      assert {:error, :invalid_input} = AudienceEngagement.analyze(nil)
    end

    test "returns error for non-map input" do
      assert {:error, :invalid_input} = AudienceEngagement.analyze("not_a_map")
    end

    test "returns error for missing required fields" do
      input = %{subscribers: 1000}
      assert {:error, {:missing_fields, _}} = AudienceEngagement.analyze(input)
    end
  end

  describe "empty_input" do
    test "rejects empty map input" do
      assert {:error, {:missing_fields, _}} = AudienceEngagement.analyze(%{})
    end

    test "rejects negative views" do
      input = %{
        subscribers: 1000,
        non_subscriber_watch_time: 1000,
        subscriber_watch_time: 1000,
        traffic_sources: %{"browse" => 2000},
        likes: 100,
        dislikes: 0,
        comments: 10,
        views: -1
      }

      assert {:error, {:invalid_value, :views}} = AudienceEngagement.analyze(input)
    end
  end

  describe "negative" do
    test "rejects negative subscribers" do
      input = %{
        subscribers: -100,
        non_subscriber_watch_time: 1000,
        subscriber_watch_time: 1000,
        traffic_sources: %{"browse" => 2000},
        likes: 100,
        dislikes: 0,
        comments: 10,
        views: 10_000
      }

      assert {:error, {:invalid_value, :subscribers}} = AudienceEngagement.analyze(input)
    end
  end
end