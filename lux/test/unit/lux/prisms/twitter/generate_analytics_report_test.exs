defmodule Lux.Prisms.Twitter.GenerateAnalyticsReportTest do
  use UnitCase, async: true

  alias Lux.Prisms.Twitter.GenerateAnalyticsReport

  @input %{
    account: "@operators",
    tweets: [
      %{
        id: "tweet-1",
        text: "Useful analytics #defi",
        impressions: 12_000,
        likes: 300,
        reposts: 60,
        replies: 20,
        url_clicks: 40
      }
    ],
    mentions: [%{author: "analyst", text: "great useful post"}],
    follower_snapshots: [
      %{date: "2026-05-01", followers: 1_000},
      %{date: "2026-05-14", followers: 1_080}
    ]
  }

  test "runs the analytics monitor through the prism" do
    assert {:ok, report} = GenerateAnalyticsReport.run(@input)

    assert report.metrics_collection.totals.impressions == 12_000
    assert report.data_aggregation.storage_snapshot.record_count == 4

    assert report.custom_reporting.sections == [
             "metrics",
             "followers",
             "hashtags",
             "sentiment",
             "alerts"
           ]

    assert report.automated_report.title == "@operators analytics report"
  end

  test "exposes input and output schemas" do
    prism = GenerateAnalyticsReport.view()

    assert prism.name == "Generate Twitter Analytics Report"
    assert prism.input_schema.required == ["tweets"]

    assert prism.output_schema.required == [
             "metrics_collection",
             "data_aggregation",
             "custom_reporting",
             "alert_system",
             "automated_report"
           ]
  end
end
