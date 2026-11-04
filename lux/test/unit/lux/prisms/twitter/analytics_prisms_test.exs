defmodule Lux.Prisms.Twitter.AnalyticsPrismsTest do
  use UnitCase, async: true

  alias Lux.Prisms.Twitter.Analytics.CollectMetricsPrism
  alias Lux.Prisms.Twitter.Analytics.SentimentAnalysisPrism
  alias Lux.Prisms.Twitter.Analytics.HashtagAnalysisPrism
  alias Lux.Prisms.Twitter.Analytics.AlertCheckPrism
  alias Lux.Prisms.Twitter.Analytics.GenerateReportPrism

  describe "CollectMetricsPrism" do
    test "collects tweet metrics" do
      input = %{"tweet_id" => "123", "raw_stats" => %{"impressions" => 1000, "likes" => 50}}
      assert {:ok, res} = CollectMetricsPrism.handler(input, %{})
      assert res.success == true
      assert res.engagement_rate > 0.0
    end
  end

  describe "SentimentAnalysisPrism" do
    test "analyzes mentions sentiment" do
      input = %{"mentions" => ["Awesome release!", "Great workteam!"]}
      assert {:ok, res} = SentimentAnalysisPrism.handler(input, %{})
      assert res.total_analyzed == 2
      assert res.average_polarity > 0.0
    end
  end

  describe "HashtagAnalysisPrism" do
    test "analyzes hashtags across tweets" do
      input = %{"tweets" => [%{"hashtags" => ["lux"], "impressions" => 500, "engagements" => 25}]}
      assert {:ok, res} = HashtagAnalysisPrism.handler(input, %{})
      assert res.hashtags_count == 1
    end
  end

  describe "AlertCheckPrism" do
    test "checks metrics against thresholds" do
      input = %{
        "metrics" => %{"engagement_rate" => 10.5, "retweets" => 120},
        "sentiment_summary" => %{"negative_ratio" => 0.05}
      }
      assert {:ok, res} = AlertCheckPrism.handler(input, %{})
      assert res.has_alerts == true
      assert res.alerts_count >= 1
    end
  end

  describe "GenerateReportPrism" do
    test "generates executive report" do
      input = %{
        "metrics" => %{"impressions" => 2000, "likes" => 100},
        "sentiment_summary" => %{"positive_count" => 5},
        "hashtag_stats" => %{"lux" => %{"count" => 1}},
        "alerts" => []
      }
      assert {:ok, res} = GenerateReportPrism.handler(input, %{})
      assert res.success == true
      assert is_binary(res.report_markdown)
    end
  end
end
