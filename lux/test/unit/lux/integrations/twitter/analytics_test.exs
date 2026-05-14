defmodule Lux.Integrations.Twitter.AnalyticsTest do
  use UnitCase, async: true

  alias Lux.Integrations.Twitter.Analytics

  @sample %{
    generated_at: "2026-05-14T04:00:00Z",
    tweets: [
      %{
        id: "tweet-1",
        label: "Launch thread",
        hashtags: ["Lux", "Agents"],
        metrics: %{likes: 120, replies: 12, reposts: 30, quotes: 6, impressions: 4_200}
      },
      %{
        id: "tweet-2",
        label: "Monitoring update",
        hashtags: ["Lux", "Monitoring"],
        metrics: %{likes: 48, replies: 5, reposts: 8, quotes: 1, impressions: 1_750}
      }
    ],
    followers: [
      %{captured_at: "2026-05-07", followers: 10_000},
      %{captured_at: "2026-05-14", followers: 10_185}
    ],
    mentions: [
      %{text: "Great launch, love the agent analytics"},
      %{text: "The dashboard has a bad bug"},
      %{text: "Question about the API docs"}
    ],
    thresholds: %{
      min_engagement_rate: 0.02,
      min_follower_delta: 25,
      max_negative_sentiment: 0.25,
      min_hashtag_interactions: 50
    }
  }

  test "aggregates engagement totals and top tweet" do
    result = Analytics.aggregate_engagement(@sample.tweets)

    assert result.tweet_count == 2
    assert result.totals.interactions == 230
    assert result.top_tweet.id == "tweet-1"
    assert result.engagement_rate > 0
  end

  test "calculates follower growth from chronological samples" do
    result = Analytics.follower_growth(Enum.reverse(@sample.followers))

    assert result.start_followers == 10_000
    assert result.end_followers == 10_185
    assert result.delta == 185
    assert result.samples == 2
  end

  test "ranks hashtags by interactions" do
    [top | _] = Analytics.hashtag_performance(@sample.tweets)

    assert top.hashtag == "lux"
    assert top.tweet_count == 2
    assert top.interactions == 230
  end

  test "rolls up mention sentiment deterministically" do
    result = Analytics.mention_sentiment(@sample.mentions)

    assert result.mention_count == 3
    assert result.positive == 1
    assert result.negative == 1
    assert result.neutral == 1
  end

  test "builds report with alerts and chart payloads" do
    report = Analytics.build_report(@sample)

    assert report.generated_at == "2026-05-14T04:00:00Z"
    assert Enum.any?(report.alerts, &(&1.type == :high_negative_sentiment))
    assert length(report.charts.engagement_by_tweet) == 2
    assert report.summary.risk_level == :watch
  end

  test "accepts string-keyed normalized payloads" do
    report =
      Analytics.build_report(%{
        "tweets" => [
          %{
            "id" => "tweet-string",
            "hashtags" => ["Lux"],
            "metrics" => %{
              "likes" => 10,
              "replies" => 1,
              "reposts" => 2,
              "quotes" => 0,
              "impressions" => 100
            }
          }
        ],
        "followers" => [%{"captured_at" => "2026-05-14", "followers" => 50}],
        "mentions" => [%{"text" => "great support"}],
        "thresholds" => %{"min_engagement_rate" => 0.01}
      })

    assert report.engagement.totals.interactions == 13

    assert report.charts.engagement_by_tweet == [
             %{id: "tweet-string", interactions: 13, label: "tweet-string"}
           ]

    assert report.sentiment.positive == 1
  end
end
