defmodule Lux.Lenses.Twitter.EngagementMetricsLensTest do
  use ExUnit.Case, async: true
  doctest Lux.Lenses.Twitter.EngagementMetricsLens

  describe "focus/1" do
    test "has correct lens metadata" do
      lens = Lux.Lenses.Twitter.EngagementMetricsLens.view()
      assert lens.name == "Twitter Engagement Metrics"
      assert lens.description != ""
      assert lens.url != ""
    end

    test "schema has expected properties" do
      lens = Lux.Lenses.Twitter.EngagementMetricsLens.view()
      properties = lens.schema[:properties]
      assert Map.has_key?(properties, "tweet_ids")
      assert Map.has_key?(properties, "user_id")
      assert Map.has_key?(properties, "metric_types")
      assert Map.has_key?(properties, "granularity")
    end

    test "default metric_types includes expected metrics" do
      lens = Lux.Lenses.Twitter.EngagementMetricsLens.view()
      metric_types_prop = lens.schema[:properties]["metric_types"]
      default = metric_types_prop[:default]
      assert "likes" in default
      assert "retweets" in default
      assert "replies" in default
      assert "impressions" in default
      assert "bookmarks" in default
    end

    test "default granularity is day" do
      lens = Lux.Lenses.Twitter.EngagementMetricsLens.view()
      granularity_prop = lens.schema[:properties]["granularity"]
      assert granularity_prop[:default] == "day"
    end

    test "output schema has expected fields" do
      lens = Lux.Lenses.Twitter.EngagementMetricsLens.view()
      output = lens.output_schema
      assert Map.has_key?(output[:properties], "metrics")
      assert Map.has_key?(output[:properties], "total_engagement")
      assert Map.has_key?(output[:properties], "average_engagement_rate")
      assert Map.has_key?(output[:properties], "top_performing_tweets")
      assert Map.has_key?(output[:properties], "daily_breakdown")
    end

    test "metric_types has enum constraint" do
      lens = Lux.Lenses.Twitter.EngagementMetricsLens.view()
      metric_types_prop = lens.schema[:properties]["metric_types"]
      items = metric_types_prop[:items]
      assert items[:enum] != nil
      assert "likes" in items[:enum]
      assert "impressions" in items[:enum]
    end

    test "granularity has enum constraint" do
      lens = Lux.Lenses.Twitter.EngagementMetricsLens.view()
      granularity_prop = lens.schema[:properties]["granularity"]
      assert granularity_prop[:enum] != nil
      assert "day" in granularity_prop[:enum]
      assert "week" in granularity_prop[:enum]
      assert "month" in granularity_prop[:enum]
    end
  end
end
