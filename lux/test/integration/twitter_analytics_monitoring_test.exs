defmodule TwitterAnalyticsMonitoringTest do
  use IntegrationCase, async: true

  alias Lux.Prisms.Twitter.GenerateAnalyticsReport

  test "runs the imported metrics to alert workflow without Twitter credentials" do
    payload = %{
      "account_id" => "spectral",
      "tweets" => [
        %{
          "id" => "launch",
          "text" => "Great launch thread for agents",
          "impressions" => 5000,
          "likes" => 350,
          "replies" => 45,
          "retweets" => 80,
          "quotes" => 10,
          "bookmarks" => 40,
          "hashtags" => ["agents", "ai"]
        }
      ],
      "mentions" => [
        %{"id" => "m1", "text" => "thanks, very useful", "followers_count" => 700},
        %{"id" => "m2", "text" => "bad setup error", "followers_count" => 35_000}
      ],
      "follower_snapshots" => [
        %{"timestamp" => "2026-06-01", "count" => 2500},
        %{"timestamp" => "2026-06-05", "count" => 2680}
      ],
      "alert_thresholds" => %{"negative_sentiment_above" => 0.25}
    }

    assert {:ok, report} = GenerateAnalyticsReport.handler(payload, %{name: "IntegrationAgent"})

    assert report.collection_boundary == "offline_import"
    assert report.report_sections.summary.tweet_count == 1
    assert report.chart_payloads.engagement_by_tweet == [
             %{id: "launch", impressions: 5000, engagements: 525}
           ]
    assert Enum.any?(report.alerts, &(&1.metric == :high_negative_sentiment))
  end
end
