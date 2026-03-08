defmodule Lux.Prisms.Twitter.Analytics.MetricsCollectorTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Twitter.Analytics.MetricsCollector

  setup do
    name = :"metrics_#{:rand.uniform(1_000_000)}"
    {:ok, pid} = MetricsCollector.start_link(name: name)
    %{pid: pid}
  end

  test "track and get tweet metrics", %{pid: pid} do
    MetricsCollector.track_tweet(pid, %{id: "t1", text: "Hello #elixir!", likes: 10, retweets: 5, replies: 2, quotes: 1, impressions: 1000})
    Process.sleep(10)
    {:ok, metrics} = MetricsCollector.get_tweet_metrics(pid, "t1")
    assert metrics.likes == 10
    assert metrics.engagement_score > 0
  end

  test "overview aggregation", %{pid: pid} do
    MetricsCollector.track_tweet(pid, %{id: "t1", text: "A", likes: 10, retweets: 5, replies: 0, quotes: 0, impressions: 500})
    MetricsCollector.track_tweet(pid, %{id: "t2", text: "B", likes: 20, retweets: 10, replies: 5, quotes: 2, impressions: 1500})
    Process.sleep(10)
    {:ok, overview} = MetricsCollector.get_overview(pid)
    assert overview.total_tweets == 2
    assert overview.total_impressions == 2000
    assert overview.total_engagement > 0
  end

  test "follower tracking", %{pid: pid} do
    MetricsCollector.track_follower_count(pid, 1000)
    MetricsCollector.track_follower_count(pid, 1050)
    Process.sleep(10)
    {:ok, overview} = MetricsCollector.get_overview(pid)
    assert overview.follower_count == 1050
    assert overview.follower_change == 50
  end

  test "follower history", %{pid: pid} do
    MetricsCollector.track_follower_count(pid, 100)
    MetricsCollector.track_follower_count(pid, 150)
    Process.sleep(10)
    {:ok, history} = MetricsCollector.get_follower_history(pid)
    assert length(history) == 2
    assert hd(history).count == 100
  end

  test "top tweets by engagement", %{pid: pid} do
    MetricsCollector.track_tweet(pid, %{id: "t1", text: "Low", likes: 1, retweets: 0, replies: 0, quotes: 0, impressions: 10})
    MetricsCollector.track_tweet(pid, %{id: "t2", text: "High", likes: 100, retweets: 50, replies: 20, quotes: 10, impressions: 5000})
    Process.sleep(10)
    {:ok, top} = MetricsCollector.get_top_tweets(pid, %{limit: 1})
    assert hd(top).id == "t2"
  end

  test "hashtag stats", %{pid: pid} do
    MetricsCollector.track_tweet(pid, %{id: "t1", text: "#elixir is great", likes: 50, retweets: 20, replies: 0, quotes: 0, impressions: 0})
    MetricsCollector.track_tweet(pid, %{id: "t2", text: "#elixir #beam", likes: 30, retweets: 10, replies: 0, quotes: 0, impressions: 0})
    Process.sleep(10)
    {:ok, hashtags} = MetricsCollector.get_hashtag_stats(pid)
    elixir = Enum.find(hashtags, fn {tag, _} -> tag == "elixir" end)
    assert elem(elixir, 1).count == 2
  end

  test "mention tracking", %{pid: pid} do
    MetricsCollector.track_mention(pid, %{text: "Thanks @bot!", user_id: "u1"})
    Process.sleep(10)
    {:ok, overview} = MetricsCollector.get_overview(pid)
    assert overview.total_mentions == 1
  end

  test "not found tweet", %{pid: pid} do
    assert {:error, :not_found} = MetricsCollector.get_tweet_metrics(pid, "nonexistent")
  end
end
