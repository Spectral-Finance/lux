defmodule Lux.Integrations.Twitter.Analytics do
  @moduledoc """
  Unified facade for Twitter Analytics and Monitoring in Lux.
  Combines engagement tracking, follower growth analysis, hashtag performance,
  sentiment evaluation, automated alert triggering, and executive report generation.
  """

  alias Lux.Integrations.Twitter.Analytics.{
    AlertEngine,
    EngagementTracker,
    FollowerGrowthTracker,
    HashtagAnalyzer,
    ReportGenerator,
    SentimentAnalyzer
  }

  # Engagement
  defdelegate aggregate_engagement(tweets), to: EngagementTracker, as: :aggregate_metrics
  defdelegate rank_top_tweets(tweets, limit \\ 5), to: EngagementTracker
  defdelegate fetch_and_analyze_engagement(user_id, opts \\ %{}), to: EngagementTracker, as: :fetch_and_analyze

  # Follower Growth
  defdelegate analyze_follower_growth(snapshots), to: FollowerGrowthTracker, as: :analyze_growth

  # Hashtags
  defdelegate extract_hashtags(text), to: HashtagAnalyzer
  defdelegate analyze_hashtags(tweets), to: HashtagAnalyzer

  # Sentiment
  defdelegate analyze_sentiment(text), to: SentimentAnalyzer, as: :analyze_text
  defdelegate analyze_mentions_sentiment(items), to: SentimentAnalyzer, as: :analyze_batch

  # Alerts
  defdelegate check_alerts(analytics_data, thresholds \\ %{}), to: AlertEngine, as: :evaluate_alerts

  # Reports
  defdelegate generate_markdown_report(analytics_data, opts \\ []), to: ReportGenerator

  @doc """
  Runs an end-to-end analytical audit across provided tweets, follower snapshots, and mentions.
  """
  @spec run_full_audit(list(map()), list(map()), list(map() | String.t()), map(), keyword()) :: map()
  def run_full_audit(tweets, snapshots \\ [], mentions \\ [], thresholds \\ %{}, report_opts \\ []) do
    engagement = aggregate_engagement(tweets)
    top_tweets = rank_top_tweets(tweets, 5)
    growth = analyze_follower_growth(snapshots)
    hashtags = analyze_hashtags(tweets)
    sentiment = analyze_mentions_sentiment(mentions)

    combined_data = %{
      metrics: engagement,
      top_tweets: top_tweets,
      growth: growth,
      hashtags: hashtags,
      sentiment: sentiment
    }

    alerts = check_alerts(combined_data, thresholds)
    final_data = Map.put(combined_data, :alerts, alerts)
    markdown_report = generate_markdown_report(final_data, report_opts)

    Map.put(final_data, :report, markdown_report)
  end
end
