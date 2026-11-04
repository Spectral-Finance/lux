defmodule Lux.Twitter.MetricsCollectorTest do
  use UnitCase, async: true

  alias Lux.Twitter.Analytics.MetricsCollector
  alias Lux.Twitter.Analytics.Aggregator

  describe "MetricsCollector" do
    setup do
      MetricsCollector.reset!()
      :ok
    end

    test "calculates engagement metrics and rate" do
      raw = %{
        impressions: 2000,
        likes: 100,
        retweets: 50,
        replies: 10,
        quotes: 5,
        bookmarks: 15
      }

      {:ok, metrics} = MetricsCollector.collect_tweet_metrics("tweet_123", raw)
      assert metrics.tweet_id == "tweet_123"
      assert metrics.impressions == 2000
      assert metrics.engagement_rate == 9.0

      history = MetricsCollector.get_history("tweet_123")
      assert length(history) == 1
    end

    test "tracks follower growth velocity" do
      growth = MetricsCollector.track_follower_growth("user_1", 1100, 1000)
      assert growth.net_gain == 100
      assert growth.growth_rate_percent == 10.0
    end
  end

  describe "Aggregator" do
    test "aggregates hashtag performance" do
      tweets = [
        %{hashtags: ["Lux", "Agents"], impressions: 1000, engagements: 50},
        %{hashtags: ["Lux", "Crypto"], impressions: 1500, engagements: 80}
      ]

      stats = Aggregator.analyze_hashtags(tweets)
      assert Map.has_key?(stats, "lux")
      assert stats["lux"].count == 2
      assert stats["lux"].total_impressions == 2500
      assert stats["lux"].total_engagements == 130
    end

    test "calculates custom viral metrics" do
      metrics = %{impressions: 10_000, retweets: 150, likes: 400, replies: 30}
      custom = Aggregator.calculate_custom_metrics(metrics)
      assert custom.viral_coefficient > 0.0
      assert custom.interaction_index > 0.0
    end
  end
end
