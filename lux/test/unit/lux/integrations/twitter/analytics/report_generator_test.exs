defmodule Lux.Integrations.Twitter.Analytics.ReportGeneratorTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Twitter.Analytics.ReportGenerator

  describe "generate_markdown_report/2" do
    test "formats comprehensive markdown report" do
      data = %{
        metrics: %{
          total_engagements: 1250,
          impressions: 25_000,
          engagement_rate: 0.05,
          virality_score: 0.22,
          likes: 800,
          retweets: 200,
          replies: 150
        },
        growth: %{
          current_followers: 12_500,
          net_follower_change: 250,
          growth_rate_percent: 2.0,
          daily_run_rate: 50.0
        },
        sentiment: %{
          positive_percentage: 65.0,
          positive_count: 65,
          neutral_count: 25,
          negative_percentage: 10.0,
          negative_count: 10,
          avg_compound_score: 0.45
        },
        hashtags: [
          %{tag: "#ai", count: 12, total_engagements: 1200, avg_engagement_per_tweet: 100.0}
        ],
        top_tweets: [
          %{"id" => "tx_101", "text" => "Breakthrough autonomous agents!", "calculated_engagement" => 550}
        ],
        alerts: []
      }

      report = ReportGenerator.generate_markdown_report(data, handle: "@Spectral_Fi")

      assert String.contains?(report, "# 📊 Twitter Performance & Monitoring Report: @Spectral_Fi")
      assert String.contains?(report, "Total Engagements:** 1250")
      assert String.contains?(report, "Current Followers:** 12500")
      assert String.contains?(report, "Positive Mentions:** 65.0%")
      assert String.contains?(report, "**#ai**")
      assert String.contains?(report, "All metrics operating normally")
    end
  end
end
