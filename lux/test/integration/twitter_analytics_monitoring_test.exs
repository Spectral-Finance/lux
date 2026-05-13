defmodule Lux.Integration.TwitterAnalyticsMonitoringTest do
  use IntegrationCase, async: true

  alias Lux.Prisms.Twitter.GenerateAnalyticsReport

  @moduletag :integration

  test "collects Twitter metrics and generates threshold alerts and reports" do
    assert {:ok, report} =
             GenerateAnalyticsReport.run(%{
               account: "@growth_ops",
               period_days: 7,
               thresholds: %{
                 engagement_rate_min: 0.05,
                 negative_sentiment_rate_max: 0.1,
                 follower_growth_rate_min: 0.01
               },
               tweets: [
                 %{
                   id: "a",
                   text: "Monitoring launch #growth",
                   published_at: "2026-05-12",
                   impressions: 20_000,
                   likes: 500,
                   reposts: 80,
                   replies: 35,
                   quotes: 10,
                   bookmarks: 60,
                   url_clicks: 90
                 },
                 %{
                   id: "b",
                   text: "Analytics report #growth #metrics",
                   published_at: "2026-05-13",
                   impressions: 25_000,
                   likes: 620,
                   reposts: 95,
                   replies: 44,
                   quotes: 18,
                   bookmarks: 72,
                   url_clicks: 110
                 }
               ],
               mentions: [
                 %{author: "fan", author_followers: 4_000, text: "great and helpful"},
                 %{author: "critic", author_followers: 9_000, text: "bad problem"}
               ],
               follower_snapshots: [
                 %{date: "2026-05-07", followers: 5_000},
                 %{date: "2026-05-14", followers: 5_120}
               ],
               custom_metrics: [
                 %{name: "Reposts per 1k impressions", formula: "reposts_per_1k_impressions"}
               ]
             })

    assert report.metrics_collection.totals.impressions == 45_000
    assert report.data_aggregation.storage_snapshot.record_count == 6
    assert Map.has_key?(report.data_aggregation.by_hashtag, "growth")
    assert report.alert_system.status == "attention_required"
    assert report.automated_report.summary |> Enum.join(" ") =~ "Engagement rate"
    assert "Alert thresholds" in report.automated_report.next_report_sections
  end
end
