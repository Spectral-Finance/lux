defmodule Lux.Twitter.Analytics.ReportGenerator do
  @moduledoc """
  Automated report generator formatting Twitter engagement metrics, sentiment distribution,
  and hashtag reach into structured Markdown and JSON reports.
  """

  @doc """
  Generates a Markdown executive analytics report.
  """
  @spec generate_markdown_report(map(), map(), map(), list(map())) :: String.t()
  def generate_markdown_report(metrics, sentiment_stats, hashtag_stats, alerts) do
    date_str = DateTime.utc_now() |> DateTime.to_date() |> Date.to_iso8601()

    alerts_md =
      if alerts == [] do
        "No threshold alerts triggered. Performance nominal."
      else
        Enum.map_join(alerts, "\n", fn a ->
          "- **[#{String.upcase(to_string(a.level))}]** `#{a.code}`: #{a.message}"
        end)
      end

    hashtags_md =
      if map_size(hashtag_stats) == 0 do
        "No hashtag data available."
      else
        Enum.map_join(hashtag_stats, "\n", fn {tag, data} ->
          "- `##{tag}`: #{data.count} mentions | #{data.total_impressions} impressions | #{data.total_engagements} engagements"
        end)
      end

    """
    # Twitter Engagement & Analytics Report (#{date_str})

    ## 1. Key Performance Metrics
    - **Total Impressions**: #{metrics[:impressions] || 0}
    - **Likes**: #{metrics[:likes] || 0}
    - **Retweets**: #{metrics[:retweets] || 0}
    - **Replies**: #{metrics[:replies] || 0}
    - **Engagement Rate**: #{metrics[:engagement_rate] || 0.0}%

    ## 2. Sentiment Breakdown
    - **Positive Mentions**: #{sentiment_stats[:positive_count] || 0} (#{Float.round((sentiment_stats[:positive_ratio] || 0.0) * 100, 1)}%)
    - **Neutral Mentions**: #{sentiment_stats[:neutral_count] || 0}
    - **Negative Mentions**: #{sentiment_stats[:negative_count] || 0} (#{Float.round((sentiment_stats[:negative_ratio] || 0.0) * 100, 1)}%)
    - **Average Polarity**: #{sentiment_stats[:average_polarity] || 0.0}

    ## 3. Top Hashtags Performance
    #{hashtags_md}

    ## 4. Operational Alerts & Triggers
    #{alerts_md}
    """
  end

  @doc """
  Generates a structured JSON analytics summary.
  """
  @spec generate_json_report(map(), map(), map(), list(map())) :: map()
  def generate_json_report(metrics, sentiment_stats, hashtag_stats, alerts) do
    %{
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      metrics: metrics,
      sentiment: sentiment_stats,
      hashtags: hashtag_stats,
      alerts: alerts
    }
  end
end
