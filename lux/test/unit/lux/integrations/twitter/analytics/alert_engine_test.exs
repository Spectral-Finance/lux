defmodule Lux.Integrations.Twitter.Analytics.AlertEngineTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Twitter.Analytics.AlertEngine

  describe "evaluate_alerts/2" do
    test "triggers engagement spike and sentiment alerts when thresholds breached" do
      analytics_data = %{
        top_tweets: [
          %{
            id: "tx_viral",
            public_metrics: %{"like_count" => 1500, "retweet_count" => 400}
          }
        ],
        sentiment: %{
          negative_percentage: 45.0
        },
        growth: %{
          net_follower_change: -100
        }
      }

      thresholds = %{
        like_threshold: 1000,
        retweet_threshold: 200,
        negative_sentiment_threshold: 30.0,
        min_follower_change: -50
      }

      alerts = AlertEngine.evaluate_alerts(analytics_data, thresholds)

      # Should have 4 alerts: like spike, retweet spike, negative sentiment, follower drop
      assert length(alerts) == 4

      metrics_alerted = Enum.map(alerts, & &1.metric)
      assert "like_count" in metrics_alerted
      assert "retweet_count" in metrics_alerted
      assert "negative_sentiment_percentage" in metrics_alerted
      assert "net_follower_change" in metrics_alerted
    end

    test "emits no alerts when operating normally" do
      analytics_data = %{
        top_tweets: [
          %{id: "tx_normal", public_metrics: %{"like_count" => 50, "retweet_count" => 10}}
        ],
        sentiment: %{negative_percentage: 5.0},
        growth: %{net_follower_change: 25}
      }

      thresholds = %{like_threshold: 500, negative_sentiment_threshold: 20.0}

      alerts = AlertEngine.evaluate_alerts(analytics_data, thresholds)
      assert alerts == []
    end
  end
end
