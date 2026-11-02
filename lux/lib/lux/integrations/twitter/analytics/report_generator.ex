defmodule Lux.Integrations.Twitter.Analytics.ReportGenerator do
  @moduledoc """
  Generates automated, structured analytical reports in Markdown and structured JSON.
  Synthesizes engagement, sentiment, follower growth, hashtags, and active alerts.
  """

  @doc """
  Generates a Markdown executive report from aggregated analytics data.
  """
  @spec generate_markdown_report(map(), keyword()) :: String.t()
  def generate_markdown_report(analytics_data, opts \\ []) do
    handle = Keyword.get(opts, :handle, "@Spectral_Fi")
    period = Keyword.get(opts, :period, "Daily Summary")
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    metrics = Map.get(analytics_data, :metrics, %{})
    growth = Map.get(analytics_data, :growth, %{})
    sentiment = Map.get(analytics_data, :sentiment, %{})
    hashtags = Map.get(analytics_data, :hashtags, [])
    top_tweets = Map.get(analytics_data, :top_tweets, [])
    alerts = Map.get(analytics_data, :alerts, [])

    """
    # 📊 Twitter Performance & Monitoring Report: #{handle}
    *Period: #{period} | Generated at: #{now}*

    ---

    ## 1. Executive Performance Metrics
    - **Total Engagements:** #{Map.get(metrics, :total_engagements, 0)}
    - **Total Impressions:** #{Map.get(metrics, :impressions, 0)}
    - **Engagement Rate:** #{Map.get(metrics, :engagement_rate, 0.0) * 100}%
    - **Virality Score:** #{Map.get(metrics, :virality_score, 0.0)}
    - **Total Likes:** #{Map.get(metrics, :likes, 0)} | **Retweets:** #{Map.get(metrics, :retweets, 0)} | **Replies:** #{Map.get(metrics, :replies, 0)}

    ---

    ## 2. Follower Growth & Audience Dynamics
    - **Current Followers:** #{Map.get(growth, :current_followers, 0)}
    - **Net Follower Change:** #{Map.get(growth, :net_follower_change, 0)}
    - **Growth Rate:** #{Map.get(growth, :growth_rate_percent, 0.0)}%
    - **Daily Velocity:** #{Map.get(growth, :daily_run_rate, 0.0)} followers/day

    ---

    ## 3. Sentiment Analysis
    - **Positive Mentions:** #{Map.get(sentiment, :positive_percentage, 0.0)}% (#{Map.get(sentiment, :positive_count, 0)})
    - **Neutral Mentions:** #{Map.get(sentiment, :neutral_count, 0)}
    - **Negative Mentions:** #{Map.get(sentiment, :negative_percentage, 0.0)}% (#{Map.get(sentiment, :negative_count, 0)})
    - **Average Sentiment Score:** #{Map.get(sentiment, :avg_compound_score, 0.0)} (-1.0 to +1.0)

    ---

    ## 4. Top Trending Hashtags
    #{format_hashtags(hashtags)}

    ---

    ## 5. Top Performing Tweets
    #{format_top_tweets(top_tweets)}

    ---

    ## 6. Active Monitoring Alerts
    #{format_alerts(alerts)}
    """
    |> String.trim()
  end

  defp format_hashtags([]), do: "*No hashtags detected in the target period.*"

  defp format_hashtags(hashtags) do
    hashtags
    |> Enum.take(5)
    |> Enum.map(fn h ->
      "- **#{h.tag}**: #{h.count} tweets | #{h.total_engagements} total engagements (avg #{h.avg_engagement_per_tweet}/tweet)"
    end)
    |> Enum.join("\n")
  end

  defp format_top_tweets([]), do: "*No tweets recorded in this period.*"

  defp format_top_tweets(tweets) do
    tweets
    |> Enum.take(3)
    |> Enum.map(fn t ->
      id = Map.get(t, :id, Map.get(t, "id", "unknown"))
      text = Map.get(t, :text, Map.get(t, "text", ""))
      eng = Map.get(t, "calculated_engagement", 0)
      "- **Tweet `#{id}`** (#{eng} engagements): #{String.slice(text, 0, 80)}..."
    end)
    |> Enum.join("\n")
  end

  defp format_alerts([]), do: "✅ *All metrics operating normally within threshold boundaries.*"

  defp format_alerts(alerts) do
    alerts
    |> Enum.map(fn a ->
      severity_badge =
        case a.severity do
          :critical -> "🚨 [CRITICAL]"
          :warning -> "⚠️ [WARNING]"
          _ -> "ℹ️ [INFO]"
        end

      "- #{severity_badge} **#{a.metric}**: #{a.message} (Triggered: #{a.triggered_at})"
    end)
    |> Enum.join("\n")
  end
end
