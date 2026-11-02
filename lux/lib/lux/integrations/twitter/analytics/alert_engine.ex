defmodule Lux.Integrations.Twitter.Analytics.AlertEngine do
  @moduledoc """
  Monitors Twitter metrics and triggers automated alerts based on configurable thresholds:
  - Viral engagement spikes (likes, retweets, impressions exceeding limits)
  - Sentiment drop warnings (negative mention ratio breaches)
  - Sudden follower drop alerts
  """

  @type alert :: %{
          id: String.t(),
          metric: String.t(),
          severity: :critical | :warning | :info,
          message: String.t(),
          value: number(),
          threshold: number(),
          triggered_at: String.t()
        }

  @doc """
  Evaluates metrics against alert rules.

  ## Options / Thresholds:
    * `:like_threshold` - Trigger alert if any tweet likes exceed this number
    * `:retweet_threshold` - Trigger alert if any tweet retweets exceed this number
    * `:negative_sentiment_threshold` - Trigger alert if negative sentiment % exceeds this number (e.g. 35.0)
    * `:min_follower_change` - Trigger alert if net follower change drops below this (e.g. -50)
  """
  @spec evaluate_alerts(map(), map()) :: list(alert())
  def evaluate_alerts(analytics_data, thresholds \\ %{}) do
    alerts = []

    now = DateTime.utc_now() |> DateTime.to_iso8601()

    # 1. Check engagement spikes
    top_tweets = Map.get(analytics_data, :top_tweets, [])
    like_thresh = Map.get(thresholds, :like_threshold, 1000)
    rt_thresh = Map.get(thresholds, :retweet_threshold, 250)

    alerts =
      Enum.reduce(top_tweets, alerts, fn tweet, acc ->
        metrics = Map.get(tweet, :public_metrics, Map.get(tweet, "public_metrics", %{}))
        likes = Map.get(metrics, "like_count", Map.get(metrics, :like_count, 0))
        rts = Map.get(metrics, "retweet_count", Map.get(metrics, :retweet_count, 0))
        tweet_id = Map.get(tweet, :id, Map.get(tweet, "id", "unknown"))

        acc =
          if likes >= like_thresh do
            [
              %{
                id: "alert_like_#{tweet_id}",
                metric: "like_count",
                severity: :info,
                message: "Viral spike! Tweet #{tweet_id} exceeded #{like_thresh} likes (#{likes}).",
                value: likes,
                threshold: like_thresh,
                triggered_at: now
              }
              | acc
            ]
          else
            acc
          end

        if rts >= rt_thresh do
          [
            %{
              id: "alert_rt_#{tweet_id}",
              metric: "retweet_count",
              severity: :info,
              message: "High virality! Tweet #{tweet_id} exceeded #{rt_thresh} retweets (#{rts}).",
              value: rts,
              threshold: rt_thresh,
              triggered_at: now
            }
            | acc
          ]
        else
          acc
        end
      end)

    # 2. Check sentiment drop
    sentiment = Map.get(analytics_data, :sentiment, %{})
    neg_pct = Map.get(sentiment, :negative_percentage, 0.0)
    neg_thresh = Map.get(thresholds, :negative_sentiment_threshold, 30.0)

    alerts =
      if neg_pct >= neg_thresh do
        [
          %{
            id: "alert_sentiment_negative",
            metric: "negative_sentiment_percentage",
            severity: :warning,
            message: "Negative sentiment surge: #{neg_pct}% of mentions are negative (threshold: #{neg_thresh}%).",
            value: neg_pct,
            threshold: neg_thresh,
            triggered_at: now
          }
          | alerts
        ]
      else
        alerts
      end

    # 3. Check follower drop
    growth = Map.get(analytics_data, :growth, %{})
    net_change = Map.get(growth, :net_follower_change, 0)
    min_change = Map.get(thresholds, :min_follower_change, -20)

    alerts =
      if net_change < min_change do
        [
          %{
            id: "alert_follower_drop",
            metric: "net_follower_change",
            severity: :critical,
            message: "Sudden audience loss detected: net change #{net_change} (threshold: #{min_change}).",
            value: net_change,
            threshold: min_change,
            triggered_at: now
          }
          | alerts
        ]
      else
        alerts
      end

    Enum.reverse(alerts)
  end
end
