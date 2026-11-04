defmodule Lux.Twitter.Analytics.AlertSystem do
  @moduledoc """
  Alert engine monitoring engagement thresholds, viral spikes, and sentiment anomalies.
  """

  require Logger

  @default_thresholds %{
    viral_engagement_rate: 8.0,
    negative_sentiment_ratio: 0.30,
    viral_retweet_threshold: 100
  }

  @doc """
  Evaluates metrics and sentiment against alert rules.
  """
  @spec evaluate_alerts(map(), map(), map()) :: list(map())
  def evaluate_alerts(metrics, sentiment_stats, custom_thresholds \\ %{}) do
    thresholds = Map.merge(@default_thresholds, custom_thresholds)
    alerts = []

    # 1. Viral engagement alert
    rate = Map.get(metrics, :engagement_rate, 0.0) || Map.get(metrics, "engagement_rate", 0.0)
    alerts =
      if rate >= thresholds.viral_engagement_rate do
        [
          %{
            level: :info,
            code: "VIRAL_ENGAGEMENT_SPIKE",
            message: "Engagement rate spike detected: #{rate}% >= #{thresholds.viral_engagement_rate}%",
            timestamp: System.system_time(:second)
          }
          | alerts
        ]
      else
        alerts
      end

    # 2. Viral retweets alert
    rts = Map.get(metrics, :retweets, 0) || Map.get(metrics, "retweets", 0)
    alerts =
      if rts >= thresholds.viral_retweet_threshold do
        [
          %{
            level: :info,
            code: "RETWEET_SURGE",
            message: "High retweet velocity: #{rts} retweets",
            timestamp: System.system_time(:second)
          }
          | alerts
        ]
      else
        alerts
      end

    # 3. Negative sentiment alert
    neg_ratio = Map.get(sentiment_stats, :negative_ratio, 0.0) || Map.get(sentiment_stats, "negative_ratio", 0.0)
    alerts =
      if neg_ratio >= thresholds.negative_sentiment_ratio do
        [
          %{
            level: :warning,
            code: "NEGATIVE_SENTIMENT_ALERT",
            message: "Negative sentiment anomaly: #{Float.round(neg_ratio * 100, 1)}% mentions negative",
            timestamp: System.system_time(:second)
          }
          | alerts
        ]
      else
        alerts
      end

    Enum.reverse(alerts)
  end
end
