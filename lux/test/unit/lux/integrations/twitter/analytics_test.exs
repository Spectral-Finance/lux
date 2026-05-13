defmodule Lux.Integrations.Twitter.AnalyticsTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.Twitter.Analytics

  @tweets [
    %{
      id: "1",
      text: "Shipping #Elixir #AI",
      like_count: 10,
      reply_count: 2,
      retweet_count: 3,
      quote_count: 1,
      bookmark_count: 4,
      impression_count: 100
    },
    %{
      id: "2",
      text: "Monitoring #elixir",
      like_count: 5,
      reply_count: 1,
      retweet_count: 1,
      quote_count: 0,
      bookmark_count: 0,
      impression_count: 50
    }
  ]

  describe "engagement_metrics/1" do
    test "normalizes totals and engagement rate" do
      metrics = Analytics.engagement_metrics(List.first(@tweets))

      assert metrics.tweet_id == "1"
      assert metrics.total_engagements == 20
      assert metrics.impression_count == 100
      assert metrics.engagement_rate == 0.2
    end
  end

  describe "aggregate_engagement/1" do
    test "aggregates tweet engagement totals and averages" do
      aggregate = Analytics.aggregate_engagement(@tweets)

      assert aggregate.tweet_count == 2
      assert aggregate.totals.like_count == 15
      assert aggregate.totals.total_engagements == 27
      assert aggregate.averages.engagements_per_tweet == 13.5
      assert [%{tweet_id: "1"}, %{tweet_id: "2"}] = aggregate.top_tweets
    end
  end

  describe "follower_growth/1" do
    test "calculates deltas from unordered snapshots" do
      growth =
        Analytics.follower_growth([
          %{captured_at: "2026-05-13T12:00:00Z", follower_count: 1_250},
          %{captured_at: "2026-05-12T12:00:00Z", follower_count: 1_000}
        ])

      assert growth.start_count == 1_000
      assert growth.end_count == 1_250
      assert growth.delta == 250
      assert growth.growth_rate == 0.25
    end
  end

  describe "hashtag_performance/1" do
    test "aggregates hashtag counts and engagement" do
      [elixir, ai] = Analytics.hashtag_performance(@tweets)

      assert elixir.hashtag == "elixir"
      assert elixir.count == 2
      assert elixir.total_engagements == 27
      assert elixir.engagements_per_post == 13.5

      assert ai.hashtag == "ai"
      assert ai.count == 1
      assert ai.total_engagements == 20
    end
  end

  describe "sentiment_rollup/1" do
    test "summarizes labeled and scored mentions" do
      rollup =
        Analytics.sentiment_rollup([
          %{sentiment: :positive},
          %{"sentiment" => "negative"},
          %{sentiment_score: 0.7},
          %{sentiment_score: -0.2},
          %{sentiment: :neutral}
        ])

      assert rollup.total_mentions == 5
      assert rollup.counts.positive == 2
      assert rollup.counts.negative == 2
      assert rollup.counts.neutral == 1
      assert rollup.negative_ratio == 0.4
    end
  end

  describe "evaluate_alerts/2" do
    test "returns triggered threshold alerts" do
      alerts =
        Analytics.evaluate_alerts(
          %{total_engagements: 27, negative_ratio: 0.4},
          [
            %{metric: :total_engagements, operator: :>=, threshold: 25, severity: :info},
            %{metric: :negative_ratio, operator: :>, threshold: 0.5, severity: :warning}
          ]
        )

      assert [
               %{
                 metric: :total_engagements,
                 operator: :>=,
                 threshold: 25,
                 value: 27,
                 severity: :info
               }
             ] = alerts
    end
  end

  describe "report/2" do
    test "builds an analytics report with alerts" do
      generated_at = ~U[2026-05-13 00:00:00Z]

      report =
        Analytics.report(
          %{
            account: "@lux",
            tweets: @tweets,
            mentions: [%{sentiment: :negative}],
            follower_snapshots: [
              %{captured_at: "2026-05-12T00:00:00Z", follower_count: 100},
              %{captured_at: "2026-05-13T00:00:00Z", follower_count: 125}
            ]
          },
          %{
            generated_at: generated_at,
            alert_rules: [%{metric: :negative_ratio, operator: :>=, threshold: 1.0, severity: :critical}]
          }
        )

      assert report.generated_at == generated_at
      assert report.account == "@lux"
      assert report.engagement.totals.total_engagements == 27
      assert report.follower_growth.delta == 25
      assert report.sentiment.negative_ratio == 1.0
      assert [%{severity: :critical}] = report.alerts
    end
  end
end
