defmodule Lux.TwitterAnalytics.StorageTest do
  use ExUnit.Case, async: false

  alias Lux.TwitterAnalytics.Storage

  setup do
    Storage.init()
    on_exit(fn -> Storage.clear_all() end)
    :ok
  end

  describe "metrics storage" do
    test "stores and retrieves a metric" do
      metric = build_metric("tweet123", "user456")
      assert :ok = Storage.store_metric(metric)
      assert {:ok, retrieved} = Storage.get_metric(metric.id)
      assert retrieved == metric
    end

    test "returns error for non-existent metric" do
      assert {:error, :not_found} = Storage.get_metric("nonexistent")
    end

    test "lists metrics by tweet ID" do
      metric1 = build_metric("tweet123", "user1")
      metric2 = build_metric("tweet123", "user2")
      metric3 = build_metric("tweet456", "user1")

      Storage.store_metric(metric1)
      Storage.store_metric(metric2)
      Storage.store_metric(metric3)

      metrics = Storage.list_metrics_by_tweet("tweet123")
      assert length(metrics) == 2
      assert Enum.all?(metrics, &(&1.tweet_id == "tweet123"))
    end

    test "lists metrics within time range" do
      now = DateTime.utc_now()
      past = DateTime.add(now, -2, :hour)
      future = DateTime.add(now, 2, :hour)

      metric_past = build_metric("t1", "u1", past)
      metric_now = build_metric("t2", "u2", now)
      metric_future = build_metric("t3", "u3", future)

      Storage.store_metric(metric_past)
      Storage.store_metric(metric_now)
      Storage.store_metric(metric_future)

      metrics = Storage.list_metrics_by_time_range(DateTime.add(now, -1, :hour), DateTime.add(now, 1, :hour))
      assert length(metrics) == 1
      assert hd(metrics).tweet_id == "t2"
    end
  end

  describe "trends storage" do
    test "stores and retrieves a trend" do
      trend = build_trend(:hashtag, "elixir")
      assert :ok = Storage.store_trend(trend)
      assert {:ok, retrieved} = Storage.get_trend(trend.id)
      assert retrieved == trend
    end

    test "lists trends by type" do
      trend1 = build_trend(:hashtag, "elixir")
      trend2 = build_trend(:hashtag, "phoenix")
      trend3 = build_trend(:user, "user123")

      Storage.store_trend(trend1)
      Storage.store_trend(trend2)
      Storage.store_trend(trend3)

      trends = Storage.list_trends_by_type(:hashtag)
      assert length(trends) == 2
      assert Enum.all?(trends, &(&1.type == :hashtag))
    end
  end

  describe "alerts storage" do
    test "stores and lists alerts by rule" do
      alert1 = build_alert("rule1")
      alert2 = build_alert("rule1")
      alert3 = build_alert("rule2")

      Storage.store_alert(alert1)
      Storage.store_alert(alert2)
      Storage.store_alert(alert3)

      alerts = Storage.list_alerts_by_rule("rule1")
      assert length(alerts) == 2
    end

    test "lists recent alerts" do
      now = DateTime.utc_now()
      past = DateTime.add(now, -2, :hour)

      alert_past = build_alert("rule1", past)
      alert_now = build_alert("rule2", now)

      Storage.store_alert(alert_past)
      Storage.store_alert(alert_now)

      recent = Storage.list_recent_alerts(DateTime.add(now, -1, :hour))
      assert length(recent) == 1
      assert hd(recent).id == alert_now.id
    end
  end

  describe "stats" do
    test "returns storage statistics" do
      Storage.store_metric(build_metric("t1", "u1"))
      Storage.store_metric(build_metric("t2", "u2"))
      Storage.store_trend(build_trend(:hashtag, "test"))
      Storage.store_alert(build_alert("rule1"))

      stats = Storage.stats()
      assert stats.metrics_count == 2
      assert stats.trends_count == 1
      assert stats.alerts_count == 1
    end
  end

  describe "clear_all" do
    test "clears all data" do
      Storage.store_metric(build_metric("t1", "u1"))
      Storage.store_trend(build_trend(:hashtag, "test"))
      Storage.store_alert(build_alert("rule1"))

      assert :ok = Storage.clear_all()

      stats = Storage.stats()
      assert stats.metrics_count == 0
      assert stats.trends_count == 0
      assert stats.alerts_count == 0
    end
  end

  ## Helpers

  defp build_metric(tweet_id, user_id, timestamp \\ nil) do
    %{
      id: generate_id(),
      tweet_id: tweet_id,
      user_id: user_id,
      timestamp: timestamp || DateTime.utc_now(),
      metrics: %{
        likes: 10,
        retweets: 5,
        replies: 3,
        quotes: 2
      },
      sentiment: :positive,
      hashtags: ["elixir"],
      metadata: %{}
    }
  end

  defp build_trend(type, identifier) do
    %{
      id: generate_id(),
      type: type,
      identifier: identifier,
      period_start: DateTime.utc_now(),
      period_end: DateTime.add(DateTime.utc_now(), 1, :hour),
      metrics: %{},
      growth_rate: 0.15
    }
  end

  defp build_alert(rule_id, timestamp \\ nil) do
    %{
      id: generate_id(),
      rule_id: rule_id,
      triggered_at: timestamp || DateTime.utc_now(),
      metric_type: :likes,
      threshold: 100,
      actual_value: 150,
      tweet_id: "tweet123"
    }
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
