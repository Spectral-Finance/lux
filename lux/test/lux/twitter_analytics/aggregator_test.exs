defmodule Lux.TwitterAnalytics.AggregatorTest do
  use ExUnit.Case, async: false

  alias Lux.TwitterAnalytics.{Aggregator, Storage}

  setup do
    {:ok, _pid} = start_supervised(Aggregator)
    Storage.clear_all()
    on_exit(fn -> Storage.clear_all() end)
    :ok
  end

  describe "record_metric/1" do
    test "records a metric successfully" do
      metric = build_metric("tweet123", "user456")
      assert :ok = Aggregator.record_metric(metric)

      # Verify it was stored
      {:ok, metrics} = Aggregator.get_tweet_metrics("tweet123")
      assert length(metrics) == 1
    end

    test "assigns ID if not provided" do
      metric = Map.delete(build_metric("tweet123", "user456"), :id)
      assert :ok = Aggregator.record_metric(metric)

      {:ok, metrics} = Aggregator.get_tweet_metrics("tweet123")
      assert length(metrics) == 1
      assert Map.has_key?(hd(metrics), :id)
    end
  end

  describe "get_tweet_metrics/1" do
    test "returns metrics for a tweet" do
      metric1 = build_metric("tweet123", "user1")
      metric2 = build_metric("tweet123", "user2")

      Aggregator.record_metric(metric1)
      Aggregator.record_metric(metric2)

      {:ok, metrics} = Aggregator.get_tweet_metrics("tweet123")
      assert length(metrics) == 2
    end

    test "returns empty list for unknown tweet" do
      {:ok, metrics} = Aggregator.get_tweet_metrics("unknown")
      assert metrics == []
    end
  end

  describe "get_engagement_summary/2" do
    test "calculates engagement summary correctly" do
      now = DateTime.utc_now()

      metric1 = build_metric("t1", "u1", now, %{likes: 10, retweets: 5, replies: 3, quotes: 2})
      metric2 = build_metric("t2", "u2", now, %{likes: 20, retweets: 10, replies: 5, quotes: 3})

      Aggregator.record_metric(metric1)
      Aggregator.record_metric(metric2)

      {:ok, summary} =
        Aggregator.get_engagement_summary(
          DateTime.add(now, -1, :hour),
          DateTime.add(now, 1, :hour)
        )

      assert summary.total_tweets == 2
      assert summary.total_likes == 30
      assert summary.total_retweets == 15
      assert summary.total_replies == 8
      assert summary.total_quotes == 5
    end
  end

  describe "get_sentiment_distribution/2" do
    test "calculates sentiment distribution" do
      now = DateTime.utc_now()

      metric1 = build_metric("t1", "u1", now, %{}, :positive)
      metric2 = build_metric("t2", "u2", now, %{}, :positive)
      metric3 = build_metric("t3", "u3", now, %{}, :negative)
      metric4 = build_metric("t4", "u4", now, %{}, :neutral)

      Enum.each([metric1, metric2, metric3, metric4], &Aggregator.record_metric/1)

      {:ok, result} =
        Aggregator.get_sentiment_distribution(
          DateTime.add(now, -1, :hour),
          DateTime.add(now, 1, :hour)
        )

      assert result.distribution[:positive] == 2
      assert result.distribution[:negative] == 1
      assert result.distribution[:neutral] == 1
      assert result.total == 4
      assert result.percentages[:positive] == 50.0
      assert result.percentages[:negative] == 25.0
    end
  end

  describe "get_hashtag_performance/3" do
    test "calculates hashtag performance" do
      now = DateTime.utc_now()

      metric1 =
        build_metric("t1", "u1", now, %{likes: 10, retweets: 5, replies: 0, quotes: 0})
        |> Map.put(:hashtags, ["elixir", "phoenix"])

      metric2 =
        build_metric("t2", "u2", now, %{likes: 20, retweets: 10, replies: 0, quotes: 0})
        |> Map.put(:hashtags, ["elixir"])

      metric3 =
        build_metric("t3", "u3", now, %{likes: 5, retweets: 2, replies: 0, quotes: 0})
        |> Map.put(:hashtags, ["phoenix"])

      Enum.each([metric1, metric2, metric3], &Aggregator.record_metric/1)

      {:ok, performance} =
        Aggregator.get_hashtag_performance(
          "elixir",
          DateTime.add(now, -1, :hour),
          DateTime.add(now, 1, :hour)
        )

      assert performance.hashtag == "elixir"
      assert performance.tweet_count == 2
      assert performance.total_engagement == 45  # (10+5) + (20+10)
      assert performance.avg_engagement == 22.5
    end
  end

  describe "get_top_tweets/1" do
    test "returns top tweets by engagement score" do
      now = DateTime.utc_now()

      # Low engagement tweet
      metric1 = build_metric("t1", "u1", now, %{likes: 1, retweets: 0, replies: 0, quotes: 0})

      # High engagement tweet (weighted: likes + retweets*2 + replies*3 + quotes*4)
      metric2 = build_metric("t2", "u2", now, %{likes: 10, retweets: 5, replies: 3, quotes: 2})

      # Medium engagement tweet
      metric3 = build_metric("t3", "u3", now, %{likes: 5, retweets: 2, replies: 1, quotes: 0})

      Enum.each([metric1, metric2, metric3], &Aggregator.record_metric/1)

      {:ok, top_tweets} = Aggregator.get_top_tweets(limit: 2)

      assert length(top_tweets) == 2
      # Should be sorted by engagement score (metric2 should be first)
      assert hd(top_tweets).tweet_id == "t2"
    end
  end

  describe "get_stats/0" do
    test "returns storage statistics" do
      Aggregator.record_metric(build_metric("t1", "u1"))
      Aggregator.record_metric(build_metric("t2", "u2"))

      {:ok, stats} = Aggregator.get_stats()
      assert stats.metrics_count == 2
    end
  end

  ## Helpers

  defp build_metric(tweet_id, user_id, timestamp \\ nil, metrics \\ nil, sentiment \\ :positive) do
    %{
      id: generate_id(),
      tweet_id: tweet_id,
      user_id: user_id,
      timestamp: timestamp || DateTime.utc_now(),
      metrics: metrics || %{likes: 10, retweets: 5, replies: 3, quotes: 2},
      sentiment: sentiment,
      hashtags: [],
      metadata: %{}
    }
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
