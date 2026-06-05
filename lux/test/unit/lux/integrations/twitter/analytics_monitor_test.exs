defmodule Lux.Integrations.Twitter.AnalyticsMonitorTest do
  use UnitCase, async: true

  alias Lux.Integrations.Twitter.AnalyticsMonitor

  describe "build_report/1" do
    test "builds a report from string keyed Twitter metric imports" do
      payload = %{
        "account_id" => "lux",
        "tweets" => [
          %{
            "id" => "t1",
            "text" => "Great launch with useful examples",
            "impressions" => "1000",
            "likes" => 70,
            "replies" => 10,
            "retweets" => 20,
            "quotes" => 5,
            "bookmarks" => 15,
            "profile_clicks" => 30,
            "hashtags" => ["#AI", "agents"]
          },
          %{
            "id" => "t2",
            "text" => "Follow-up thread",
            "impressions" => 500,
            "likes" => 10,
            "hashtags" => ["ai"]
          }
        ],
        "mentions" => [
          %{"id" => "m1", "text" => "awesome work", "followers_count" => 1200},
          %{"id" => "m2", "text" => "broken docs", "followers_count" => 20_000}
        ],
        "follower_snapshots" => [
          %{"timestamp" => "2026-06-01T00:00:00Z", "count" => 1000},
          %{"timestamp" => "2026-06-05T00:00:00Z", "count" => 1080}
        ]
      }

      assert {:ok, report} = AnalyticsMonitor.build_report(payload)

      assert report.account_id == "lux"
      assert report.collection_boundary == "offline_import"
      assert report.metrics.tweet_count == 2
      assert report.metrics.impressions == 1500
      assert report.metrics.engagements == 160
      assert report.metrics.engagement_rate == 0.106667
      assert report.follower_growth.delta == 80
      assert report.follower_growth.trend == :up
      assert report.mention_sentiment.positive == 1
      assert report.mention_sentiment.negative == 1
      assert [%{hashtag: "ai", uses: 2} | _] = report.hashtag_performance
      assert [%{id: "t1", sentiment: :positive} | _] = report.tweet_metrics
    end

    test "bounds malformed metrics and produces data quality notes" do
      payload = %{
        tweets: [
          %{id: "bad", text: "", impressions: "-100", likes: "not-a-number", replies: 3}
        ],
        mentions: []
      }

      assert {:ok, report} = AnalyticsMonitor.build_report(payload)

      assert report.metrics.impressions == 0
      assert report.metrics.engagements == 3
      assert report.metrics.engagement_rate == 0.0
      assert "No mentions were provided; sentiment sample is empty." in report.quality_notes
      assert "Follower growth needs at least two snapshots." in report.quality_notes
      assert "Tweet text is missing." in hd(report.tweet_metrics).quality_notes
    end

    test "evaluates alert thresholds and custom metrics" do
      payload = %{
        tweets: [
          %{id: "t1", text: "bad scam", impressions: 1000, likes: 1, replies: 1, hashtags: ["risk"]},
          %{id: "t2", text: "bad support", impressions: 1000, likes: 1, hashtags: ["risk"]}
        ],
        mentions: [
          %{id: "m1", text: "bad scam", followers_count: 150_000}
        ],
        follower_snapshots: [
          %{timestamp: "2026-06-01", count: 1000},
          %{timestamp: "2026-06-02", count: 990}
        ],
        alert_thresholds: %{
          engagement_rate_below: 0.01,
          negative_sentiment_above: 0.5,
          follower_growth_below: 0,
          hashtag_engagement_below: 0.01
        },
        custom_metrics: [
          %{name: "engagement_per_impression", numerator: "engagements", denominator: "impressions"},
          %{name: "likes_per_impression", numerator: "likes", denominator: "impressions"}
        ]
      }

      assert {:ok, report} = AnalyticsMonitor.build_report(payload)

      assert Enum.any?(report.alerts, &(&1.metric == :low_engagement_rate))
      assert Enum.any?(report.alerts, &(&1.metric == :high_negative_sentiment))
      assert Enum.any?(report.alerts, &(&1.metric == :low_follower_growth))
      assert Enum.any?(report.alerts, &(&1.metric == :low_hashtag_engagement and &1.scope == "risk"))
      assert [%{name: "engagement_per_impression", value: 0.002} | _] = report.custom_metrics
      assert Enum.any?(report.custom_metrics, &(&1.name == "likes_per_impression" and &1.value == 0.001))
      assert [%{followers_count: 150_000} | _] = report.mention_sentiment.high_influence_negative_mentions
    end

    test "rejects non-map payloads" do
      assert {:error, "Twitter analytics payload must be a map"} = AnalyticsMonitor.build_report([])
    end
  end
end
