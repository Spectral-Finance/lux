defmodule Lux.Prisms.Twitter.Analytics.ReportGeneratorTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Twitter.Analytics.{MetricsCollector, ReportGenerator}

  test "generate full report" do
    name = :"rpt_#{:rand.uniform(1_000_000)}"
    {:ok, pid} = MetricsCollector.start_link(name: name)
    MetricsCollector.track_tweet(pid, %{id: "t1", text: "#ai is cool", likes: 50, retweets: 20, replies: 5, quotes: 2, impressions: 3000})
    MetricsCollector.track_follower_count(pid, 1000)
    Process.sleep(10)

    {:ok, report} = ReportGenerator.generate(pid)
    assert report.overview.total_tweets == 1
    assert length(report.top_tweets) >= 1
    assert report.generated_at
  end

  test "sentiment report" do
    texts = [
      "I love this amazing product!",
      "Terrible customer service, horrible experience",
      "The update is okay I guess"
    ]
    {:ok, report} = ReportGenerator.sentiment_report(texts)
    assert report.summary.total == 3
    assert length(report.samples) == 3
  end

  test "sentiment report empty" do
    {:ok, report} = ReportGenerator.sentiment_report([])
    assert report.summary.total == 0
    assert report.samples == []
  end

  test "sentiment report large batch truncates samples" do
    texts = for i <- 1..30, do: "Tweet number #{i} is great"
    {:ok, report} = ReportGenerator.sentiment_report(texts)
    assert report.summary.total == 30
    assert length(report.samples) == 20
  end

  test "generate report with no data" do
    name = :"rpt_empty_#{:rand.uniform(1_000_000)}"
    {:ok, pid} = MetricsCollector.start_link(name: name)
    {:ok, report} = ReportGenerator.generate(pid)
    assert report.overview.total_tweets == 0
    assert report.top_tweets == []
  end

  test "generate report with multiple tweets" do
    name = :"rpt_multi_#{:rand.uniform(1_000_000)}"
    {:ok, pid} = MetricsCollector.start_link(name: name)
    for i <- 1..10 do
      MetricsCollector.track_tweet(pid, %{id: "t#{i}", text: "#test tweet #{i}", likes: i * 10, retweets: i * 5, replies: i, quotes: 0, impressions: i * 100})
    end
    Process.sleep(10)

    {:ok, report} = ReportGenerator.generate(pid)
    assert report.overview.total_tweets == 10
    assert length(report.top_tweets) == 5
  end
end
