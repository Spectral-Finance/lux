defmodule Lux.Prisms.Twitter.EngagementReportPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.Twitter.EngagementAlertPrism
  alias Lux.Prisms.Twitter.EngagementReportPrism
  alias Lux.Prisms.Twitter.ReportPayloadPrism

  @input %{
    tweets: [
      %{
        id: "tweet-1",
        label: "Launch thread",
        hashtags: ["Lux"],
        metrics: %{likes: 100, replies: 10, reposts: 20, quotes: 5, impressions: 2_000}
      }
    ],
    followers: [
      %{captured_at: "2026-05-07", followers: 200},
      %{captured_at: "2026-05-14", followers: 180}
    ],
    mentions: [%{text: "bad issue"}, %{text: "great work"}],
    thresholds: %{min_follower_delta: 0, max_negative_sentiment: 0.25}
  }

  test "engagement report prism returns full analytics report" do
    {:ok, report} = EngagementReportPrism.run(@input)

    assert report.engagement.totals.interactions == 135
    assert report.follower_growth.delta == -20
    assert [%{hashtag: "lux"}] = report.hashtags
  end

  test "alert prism returns alerts and summary" do
    {:ok, result} = EngagementAlertPrism.run(@input)

    assert Enum.any?(result.alerts, &(&1.type == :negative_follower_growth))
    assert result.summary.risk_level == :watch
  end

  test "report payload prism returns dashboard payload" do
    {:ok, result} = ReportPayloadPrism.run(@input)

    assert result.summary.headline =~ "Tracked 1 tweets"
    assert [%{hashtag: "lux"}] = result.top_hashtags
    assert [%{id: "tweet-1"}] = result.charts.engagement_by_tweet
  end

  test "report prism exposes schema metadata" do
    prism = EngagementReportPrism.view()

    assert prism.input_schema.required == ["tweets"]
    assert "engagement" in prism.output_schema.required
  end
end
