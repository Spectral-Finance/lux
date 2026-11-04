defmodule Lux.Integrations.Twitter.Analytics.MonitorTest do
  use ExUnit.Case, async: false

  @moduletag :unit

  alias Lux.Integrations.Twitter.Analytics.Monitor

  @api_key "test-twitter-api-key-192-0-2-3"
  @tweet_id "1920234567890123456"

  setup do
    server = start_monitor_or_nil()
    on_exit(fn ->
      if not is_nil(server) do
        Process.exit(server, :kill)
      end
    end)
    %{server: server}
  end

  defp start_monitor_or_nil do
    try do
      case Monitor.start_link() do
        {:ok, server} -> server
        _other -> nil
      end
    rescue
      _ -> nil
    end
  end

  describe "regression (#59)" do
    test "analytics monitor module is available", %{server: server} do
      assert Code.ensure_loaded?(Monitor),
             "AssertionError: Lux.Integrations.Twitter.Analytics.Monitor is not available"
    end
  end

  describe "happy path" do
    test "records tweet engagement metrics", %{server: server} do
      assert {:ok, metric} =
               Monitor.record_engagement(
                 server,
                 @tweet_id,
                 %{likes: 10, retweets: 5, replies: 2, impressions: 100, mentions: 3}
               )

      assert metric.id == @tweet_id
      assert metric.kind == :engagement
      assert metric.value == 120

      assert metric.data.metrics == %{
               likes: 10,
               retweets: 5,
               replies: 2,
               impressions: 100,
               mentions: 3
             }
    end

    test "records engagement with optional metrics defaulting to zero", %{server: server} do
      assert {:ok, metric} = Monitor.record_engagement(server, @tweet_id, %{likes: 7})

      assert metric.value == 7

      assert metric.data.metrics == %{
               likes: 7,
               retweets: 0,
               replies: 0,
               impressions: 0,
               mentions: 0
             }
    end

    test "rejects duplicate tweet_id (idempotent, zero double-spend)", %{server: server} do
      assert {:ok, _} = Monitor.record_engagement(server, @tweet_id, %{likes: 1})
      assert {:error, :duplicate} = Monitor.record_engagement(server, @tweet_id, %{likes: 1})
    end

    test "tracks follower growth and delta", %{server: server} do
      assert {:ok, first} = Monitor.track_follower_growth(server, "alice", 1000)

      assert first.value == 1000
      assert first.data.growth == 1000
      assert first.data.previous == 0

      assert {:ok, second} = Monitor.track_follower_growth(server, "alice", 1020)

      assert second.value == 1020
      assert second.data.growth == 20
      assert second.data.previous == 1000
    end

    test "analyzes hashtag performance", %{server: server} do
      tweets = [
        %{text: "hello #lux", engagement: %{likes: 5, retweets: 2}},
        %{text: "hey #lux", engagement: %{likes: 3}}
      ]

      assert {:ok, analysis} = Monitor.analyze_hashtag(server, "#lux", tweets)

      assert analysis.hashtag == "#lux"
      assert analysis.tweet_count == 2
      assert analysis.total_engagement == 10
      assert analysis.average_engagement == 5.0
    end

    test "collects and aggregates all stored metrics", %{server: server} do
      assert {:ok, _} = Monitor.record_engagement(server, @tweet_id, %{likes: 3, retweets: 2})
      assert {:ok, _} = Monitor.track_follower_growth(server, "alice", 100)

      {:ok, data} = Monitor.collect_metrics(server)

      assert length(data.engagements) == 1
      assert length(data.followers) == 1
      assert data.totals.total_likes == 3
      assert data.totals.total_retweets == 2
      assert data.totals.total_metrics == 2
    end

    test "defines custom metrics and fires threshold alerts", %{server: server} do
      assert {:ok, metric} = Monitor.define_metric(server, "daily_mentions", {10, :above})

      assert metric.value == 0
      assert metric.threshold == {10, :above}

      assert {:ok, 5} = Monitor.increment_metric(server, "daily_mentions", 5)
      assert {:ok, []} = Monitor.check_alerts(server)

      assert {:ok, 11} = Monitor.increment_metric(server, "daily_mentions", 6)

      assert {:ok, alerts} = Monitor.check_alerts(server)
      assert length(alerts) == 1
      assert hd(alerts).metric_id == "daily_mentions"
      assert hd(alerts).direction == :above
      assert hd(alerts).value == 11
    end

    test "generates a customizable report", %{server: server} do
      assert {:ok, _} = Monitor.record_engagement(server, @tweet_id, %{likes: 4})

      assert {:ok, report} = Monitor.generate_report(server)

      assert Map.has_key?(report, :summary)
      assert Map.has_key?(report, :metrics)
      assert Map.has_key?(report, :alerts)
      assert report.summary.total_metrics >= 1

      assert {:ok, summary_only} =
               Monitor.generate_report(server, include: [:summary])

      assert Map.has_key?(summary_only, :summary)
      assert not Map.has_key?(summary_only, :metrics)
    end

    test "gets, lists and deletes metrics", %{server: server} do
      assert {:ok, _} = Monitor.record_engagement(server, "t-del", %{likes: 1})

      assert {:ok, metric} = Monitor.get_metric(server, "t-del")
      assert metric.id == "t-del"

      assert {:ok, metrics} = Monitor.list_metrics(server)
      ids = Enum.map(metrics, & &1.id)
      assert "t-del" in ids

      assert {:ok, :deleted} = Monitor.delete_metric(server, "t-del")
      assert {:error, :not_found} = Monitor.get_metric(server, "t-del")
    end

    test "analyzes sentiment of mentions", %{server: server} do
      assert {:ok, pos} = Monitor.analyze_sentiment("This is a great amazing product, I love it!")

      assert pos.sentiment == :positive
      assert pos.confidence > 0
      assert pos.details.pos > pos.details.neg

      assert {:ok, neg} = Monitor.analyze_sentiment("Terrible awful hate this bad product")

      assert neg.sentiment == :negative
      assert neg.details.neg > neg.details.pos

      assert {:ok, neu} = Monitor.analyze_sentiment("The meeting is at noon")

      assert neu.sentiment == :neutral
    end
  end

  describe "null input" do
    test "rejects null tweet_id without crashing", %{server: server} do
      assert {:error, :invalid_tweet_id} = Monitor.record_engagement(server, nil, %{likes: 1})
      assert {:error, :invalid_tweet_id} = Monitor.record_engagement(server, nil)
    end

    test "rejects null metrics, account and count", %{server: server} do
      assert {:error, :invalid_metrics} = Monitor.record_engagement(server, @tweet_id, nil)
      assert {:error, :invalid_account} = Monitor.track_follower_growth(server, nil, 100)
      assert {:error, :invalid_count} = Monitor.track_follower_growth(server, "alice", nil)
    end

    test "rejects null metric id", %{server: server} do
      assert {:error, :not_found} = Monitor.get_metric(server, nil)
      assert {:error, :invalid_metric_id} = Monitor.delete_metric(server, nil)
    end
  end

  describe "empty input" do
    test "rejects empty or whitespace-only tweet_id", %{server: server} do
      assert {:error, :invalid_tweet_id} = Monitor.record_engagement(server, "", %{likes: 1})
      assert {:error, :invalid_tweet_id} = Monitor.record_engagement(server, "   ", %{likes: 1})
    end

    test "rejects empty or whitespace-only account", %{server: server} do
      assert {:error, :invalid_account} = Monitor.track_follower_growth(server, "", 10)
      assert {:error, :invalid_account} = Monitor.track_follower_growth(server, "  ", 10)
    end

    test "rejects invalid hashtag", %{server: server} do
      assert {:error, :invalid_hashtag} = Monitor.analyze_hashtag(server, "", [])
      assert {:error, :invalid_hashtag} = Monitor.analyze_hashtag(server, "lux", [])
      assert {:error, :invalid_hashtag} = Monitor.analyze_hashtag(server, "#", [])
    end

    test "rejects empty metric name", %{server: server} do
      assert {:error, :invalid_name} = Monitor.define_metric(server, "", nil)
      assert {:error, :invalid_name} = Monitor.define_metric(server, "   ", nil)
    end

    test "analyzes empty text as neutral", %{server: server} do
      assert {:ok, result} = Monitor.analyze_sentiment("")

      assert result.sentiment == :neutral
      assert result.confidence == 0
      assert result.details.pos == 0
      assert result.details.neg == 0
      assert result.details.compound == 0
    end
  end

  describe "boundary" do
    test "accepts zero-valued metrics at the lower bound", %{server: server} do
      assert {:ok, metric} =
               Monitor.record_engagement(server, @tweet_id, %{likes: 0, retweets: 0})

      assert metric.value == 0
    end

    test "enforces strict threshold boundary (half-open interval)", %{server: server} do
      assert {:ok, _} = Monitor.define_metric(server, "grace", {0, :above})

      assert {:ok, _} = Monitor.update_metric(server, "grace", 0)
      assert {:ok, []} = Monitor.check_alerts(server)

      assert {:ok, _} = Monitor.update_metric(server, "grace", 1)
      assert {:ok, alerts} = Monitor.check_alerts(server)
      assert length(alerts) == 1
    end

    test "stores values at the upper integer boundary", %{server: server} do
      max = 2 ** 62 - 1

      assert {:ok, ^max} = Monitor.increment_metric(server, "top", max)

      assert {:ok, metric} = Monitor.get_metric(server, "top")
      assert metric.value == max
    end
  end

  describe "negative" do
    test "refuses unauthorized callers with a typed error", %{server: server} do
      {:ok, secured} = Monitor.start_link(api_key: @api_key)
      on_exit(fn -> Process.exit(secured, :kill) end)

      assert {:error, :unauthorized} =
               Monitor.record_engagement(secured, @tweet_id, %{likes: 1}, api_key: "wrong-key")

      assert {:error, :unauthorized} =
               Monitor.record_engagement(secured, @tweet_id, %{likes: 1})

      assert {:ok, _} =
               Monitor.record_engagement(secured, @tweet_id, %{likes: 1}, api_key: @api_key)
    end

    test "rejects negative values with typed errors", %{server: server} do
      assert {:error, :negative_value} =
               Monitor.record_engagement(server, @tweet_id, %{likes: -1})

      assert {:error, :negative_value} = Monitor.track_follower_growth(server, "alice", -5)
    end

    test "rejects malformed data with typed errors", %{server: server} do
      assert {:error, :invalid_tweet_id} = Monitor.record_engagement(server, 123, %{likes: 1})
      assert {:error, :invalid_count} = Monitor.track_follower_growth(server, "alice", "many")

      assert {:error, :invalid_metrics} =
               Monitor.record_engagement(server, @tweet_id, %{likes: "many"})

      assert {:error, :invalid_threshold} = Monitor.define_metric(server, "m", {:oops, :above})
    end

    test "returns not_found for unknown metrics", %{server: server} do
      assert {:error, :not_found} = Monitor.get_metric(server, "does-not-exist")
      assert {:error, :not_found} = Monitor.delete_metric(server, "does-not-exist")
    end
  end

  describe "concurrency" do
    test "concurrent increments of the same metric are atomic (no double-spend)", %{
      server: server
    } do
      metric_id = "concurrent-metric"
      n = 100

      tasks = for _ <- 1..n, do: Task.async(fn -> Monitor.increment_metric(server, metric_id) end)
      results = Enum.map(tasks, &Task.await(&1, 5000))

      assert Enum.all?(results, &match?({:ok, _}, &1))

      assert {:ok, metric} = Monitor.get_metric(server, metric_id)
      assert metric.value == n
    end

    test "concurrent duplicate records never double-spend", %{server: server} do
      n = 50

      tasks =
        for _ <- 1..n,
            do: Task.async(fn -> Monitor.record_engagement(server, @tweet_id, %{likes: 1}) end)

      results = Enum.map(tasks, &Task.await(&1, 5000))

      successes = Enum.count(results, &match?({:ok, _}, &1))
      duplicates = Enum.count(results, &match?({:error, :duplicate}, &1))

      assert successes == 1
      assert duplicates == n - 1
    end
  end
end
