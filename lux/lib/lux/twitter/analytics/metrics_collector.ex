defmodule Lux.Twitter.Analytics.MetricsCollector do
  @moduledoc """
  Real-time Twitter metrics collector, engagement evaluator, and follower growth tracker.
  """

  @type tweet_metrics :: %{
          tweet_id: String.t(),
          impressions: non_neg_integer(),
          retweets: non_neg_integer(),
          likes: non_neg_integer(),
          replies: non_neg_integer(),
          quotes: non_neg_integer(),
          bookmarks: non_neg_integer(),
          engagement_rate: float()
        }

  @doc """
  Collects metrics for a single tweet and calculates engagement rate.
  """
  @spec collect_tweet_metrics(String.t(), map()) :: {:ok, tweet_metrics()}
  def collect_tweet_metrics(tweet_id, raw_stats \\ %{}) do
    impressions = Map.get(raw_stats, "impressions") || Map.get(raw_stats, :impressions, 1500)
    retweets = Map.get(raw_stats, "retweets") || Map.get(raw_stats, :retweets, 45)
    likes = Map.get(raw_stats, "likes") || Map.get(raw_stats, :likes, 180)
    replies = Map.get(raw_stats, "replies") || Map.get(raw_stats, :replies, 12)
    quotes = Map.get(raw_stats, "quotes") || Map.get(raw_stats, :quotes, 8)
    bookmarks = Map.get(raw_stats, "bookmarks") || Map.get(raw_stats, :bookmarks, 25)

    total_interactions = retweets + likes + replies + quotes + bookmarks
    rate = if impressions > 0, do: Float.round((total_interactions / impressions) * 100, 2), else: 0.0

    metrics = %{
      tweet_id: tweet_id,
      impressions: impressions,
      retweets: retweets,
      likes: likes,
      replies: replies,
      quotes: quotes,
      bookmarks: bookmarks,
      engagement_rate: rate,
      collected_at: System.system_time(:second)
    }

    record_metric_history(tweet_id, metrics)
    {:ok, metrics}
  end

  @doc """
  Tracks follower count trajectory and computes growth velocity.
  """
  @spec track_follower_growth(String.t(), non_neg_integer(), non_neg_integer()) :: map()
  def track_follower_growth(user_id, current_followers, previous_followers) do
    net_gain = current_followers - previous_followers
    growth_rate =
      if previous_followers > 0 do
        Float.round((net_gain / previous_followers) * 100, 2)
      else
        0.0
      end

    %{
      user_id: user_id,
      current_followers: current_followers,
      previous_followers: previous_followers,
      net_gain: net_gain,
      growth_rate_percent: growth_rate,
      timestamp: System.system_time(:second)
    }
  end

  defp record_metric_history(tweet_id, metrics) do
    history = Process.get(:lux_twitter_metrics_history, %{})
    list = Map.get(history, tweet_id, [])
    Process.put(:lux_twitter_metrics_history, Map.put(history, tweet_id, [metrics | list]))
  end

  @doc """
  Retrieves recorded metrics history for a tweet.
  """
  @spec get_history(String.t()) :: list(tweet_metrics())
  def get_history(tweet_id) do
    history = Process.get(:lux_twitter_metrics_history, %{})
    Map.get(history, tweet_id, [])
  end

  @doc """
  Resets metrics collector state.
  """
  @spec reset!() :: :ok
  def reset! do
    Process.put(:lux_twitter_metrics_history, %{})
    :ok
  end
end
