defmodule Lux.Integrations.Twitter.AnalyticsMonitorTest do
  use UnitCase, async: true

  alias Lux.Integrations.Twitter.AnalyticsMonitor

  @brief %{
    account: "@lux_ai",
    period_days: 14,
    thresholds: %{
      engagement_rate_min: 0.04,
      negative_sentiment_rate_max: 0.2,
      follower_growth_rate_min: 0.02
    },
    report_sections: ["metrics", "followers", "hashtags", "sentiment", "alerts"],
    custom_metrics: [
      %{name: "Reposts per 1k impressions", formula: "reposts_per_1k_impressions"},
      %{name: "Clicks per 1k impressions", formula: "clicks_per_1k_impressions"}
    ],
    follower_snapshots: [
      %{date: "2026-05-01", followers: 10_000, following: 120, tweet_count: 500},
      %{date: "2026-05-14", followers: 10_850, following: 125, tweet_count: 524}
    ],
    tweets: [
      %{
        id: "tweet-1",
        text: "Shipping agent analytics #ai #agents",
        published_at: "2026-05-03",
        impressions: 40_000,
        likes: 900,
        reposts: 150,
        replies: 70,
        quotes: 30,
        bookmarks: 180,
        url_clicks: 240
      },
      %{
        id: "tweet-2",
        text: "New monitoring dashboard #agents #analytics",
        published_at: "2026-05-10",
        impressions: 60_000,
        likes: 1_500,
        retweets: 260,
        replies: 140,
        quotes: 55,
        bookmarks: 310,
        url_clicks: 420
      }
    ],
    mentions: [
      %{author: "builder_a", author_followers: 12_000, text: "Great launch, very useful"},
      %{author: "builder_b", author_followers: 500, text: "The dashboard is good"},
      %{author: "critic", author_followers: 8_000, text: "This is broken and bad"}
    ]
  }

  describe "run/1" do
    test "builds a complete Twitter analytics report" do
      assert {:ok, report} = AnalyticsMonitor.run(@brief)

      assert report.account == "@lux_ai"
      assert report.metrics_collection.tweet_count == 2
      assert report.metrics_collection.totals.impressions == 100_000
      assert report.metrics_collection.totals.engagements == 4_255
      assert report.metrics_collection.rates.engagement_rate == 0.0425
      assert report.data_aggregation.storage_snapshot.record_count == 7
      assert report.follower_growth.followers_gained == 850
      assert report.hashtag_performance.top_hashtag == "agents"
      assert report.mention_sentiment.sentiment_counts["negative"] == 1
      assert report.alert_system.status == "attention_required"
      assert "Real-time metrics collection" in report.automated_report.next_report_sections
      assert length(report.custom_reporting.custom_metrics) == 2
      assert length(report.action_plan) == 4
    end

    test "accepts string-keyed exports" do
      brief = %{
        "account" => "@string_keys",
        "tweets" => [
          %{
            "id" => "1",
            "text" => "Great metrics #growth",
            "impressions" => "10000",
            "likes" => "300",
            "retweets" => "50",
            "replies" => "20"
          }
        ],
        "mentions" => [%{"author" => "fan", "text" => "love this useful update"}]
      }

      assert {:ok, report} = AnalyticsMonitor.run(brief)
      assert report.account == "@string_keys"
      assert report.metrics_collection.totals.impressions == 10_000
      assert report.hashtag_performance.top_hashtag == "growth"
      assert report.mention_sentiment.sentiment_counts["positive"] == 1
    end

    test "rejects non-map input" do
      assert {:error, "Expected a map with Twitter analytics data"} = AnalyticsMonitor.run([])
    end
  end

  describe "component reports" do
    test "collects, aggregates, and alerts on metrics" do
      metrics = AnalyticsMonitor.collect_metrics(@brief)
      aggregation = AnalyticsMonitor.aggregate_data(@brief)
      alerts = AnalyticsMonitor.alert_system(@brief)

      assert metrics.data_quality.status == "complete"
      assert Map.has_key?(aggregation.by_hashtag, "agents")
      assert [%{type: "negative_sentiment_above_threshold"}] = alerts.alerts
    end

    test "builds custom reports and optimization recommendations" do
      assert %{generated_reports: reports, custom_metrics: custom_metrics} =
               AnalyticsMonitor.custom_report(@brief)

      assert Enum.any?(reports, &(&1.section == "metrics"))
      assert Enum.any?(custom_metrics, &(&1.value != nil))
      assert %{recommendations: [_ | _]} = AnalyticsMonitor.performance_optimization(@brief)
    end
  end
end
