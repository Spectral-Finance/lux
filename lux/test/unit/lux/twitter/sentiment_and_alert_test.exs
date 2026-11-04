defmodule Lux.Twitter.SentimentAndAlertTest do
  use UnitCase, async: true

  alias Lux.Twitter.Analytics.Sentiment
  alias Lux.Twitter.Analytics.AlertSystem
  alias Lux.Twitter.Analytics.ReportGenerator

  describe "Sentiment analysis" do
    test "classifies positive text" do
      res = Sentiment.analyze_text("This is an amazing and innovative project, congrats!")
      assert res.classification == :positive
      assert res.polarity > 0.0
    end

    test "classifies negative text" do
      res = Sentiment.analyze_text("Terrible scam dump and awful crash")
      assert res.classification == :negative
      assert res.polarity < 0.0
    end

    test "aggregates sentiment batch" do
      batch = [
        "Great win and bullish update",
        "Terrible drop and crash",
        "Neutral discussion about parameters"
      ]

      summary = Sentiment.aggregate_sentiment(batch)
      assert summary.total_analyzed == 3
      assert summary.positive_count == 1
      assert summary.negative_count == 1
      assert summary.neutral_count == 1
    end
  end

  describe "AlertSystem" do
    test "triggers viral spike alert when threshold exceeded" do
      metrics = %{engagement_rate: 12.5, retweets: 150}
      sentiment = %{negative_ratio: 0.05}

      alerts = AlertSystem.evaluate_alerts(metrics, sentiment)
      codes = Enum.map(alerts, & &1.code)
      assert "VIRAL_ENGAGEMENT_SPIKE" in codes
      assert "RETWEET_SURGE" in codes
    end

    test "triggers negative sentiment alert" do
      metrics = %{engagement_rate: 2.0, retweets: 5}
      sentiment = %{negative_ratio: 0.45}

      alerts = AlertSystem.evaluate_alerts(metrics, sentiment)
      assert length(alerts) == 1
      assert hd(alerts).code == "NEGATIVE_SENTIMENT_ALERT"
    end
  end

  describe "ReportGenerator" do
    test "generates markdown and json reports" do
      metrics = %{impressions: 5000, likes: 200, retweets: 50, replies: 20, engagement_rate: 5.4}
      sentiment = %{positive_count: 8, neutral_count: 2, negative_count: 1, positive_ratio: 0.72, negative_ratio: 0.09, average_polarity: 0.63}
      hashtags = %{"lux" => %{count: 5, total_impressions: 4000, total_engagements: 200}}
      alerts = [%{level: :info, code: "TEST", message: "Nominal"}]

      md = ReportGenerator.generate_markdown_report(metrics, sentiment, hashtags, alerts)
      assert String.contains?(md, "Twitter Engagement & Analytics Report")
      assert String.contains?(md, "5000")

      json = ReportGenerator.generate_json_report(metrics, sentiment, hashtags, alerts)
      assert is_map(json)
      assert json.metrics.impressions == 5000
    end
  end
end
