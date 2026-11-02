defmodule Lux.Integrations.Twitter.Analytics.EngagementTracker do
  @moduledoc """
  Tracks, computes, and aggregates engagement metrics for Twitter tweets:
  - Like count, Retweet count, Reply count, Quote count, Bookmark count, Impression count
  - Custom metrics: Engagement Rate per Impression, Virality Score, Amplification Rate
  - Ranking top-performing tweets by engagement
  """

  alias Lux.Integrations.Twitter.Client

  @type engagement_metrics :: %{
          likes: non_neg_integer(),
          retweets: non_neg_integer(),
          replies: non_neg_integer(),
          quotes: non_neg_integer(),
          bookmarks: non_neg_integer(),
          impressions: non_neg_integer(),
          total_engagements: non_neg_integer(),
          engagement_rate: float(),
          virality_score: float()
        }

  @doc """
  Computes aggregated engagement metrics across a list of tweet data maps.
  """
  @spec aggregate_metrics(list(map())) :: engagement_metrics()
  def aggregate_metrics(tweets) when is_list(tweets) do
    init = %{
      likes: 0,
      retweets: 0,
      replies: 0,
      quotes: 0,
      bookmarks: 0,
      impressions: 0
    }

    totals =
      Enum.reduce(tweets, init, fn tweet, acc ->
        metrics = extract_metrics(tweet)

        %{
          likes: acc.likes + Map.get(metrics, "like_count", 0),
          retweets: acc.retweets + Map.get(metrics, "retweet_count", 0),
          replies: acc.replies + Map.get(metrics, "reply_count", 0),
          quotes: acc.quotes + Map.get(metrics, "quote_count", 0),
          bookmarks: acc.bookmarks + Map.get(metrics, "bookmark_count", 0),
          impressions: acc.impressions + Map.get(metrics, "impression_count", 0)
        }
      end)

    total_engagements = totals.likes + totals.retweets + totals.replies + totals.quotes + totals.bookmarks

    engagement_rate =
      if totals.impressions > 0 do
        Float.round(total_engagements / totals.impressions, 4)
      else
        0.0
      end

    virality_score =
      if total_engagements > 0 do
        Float.round((totals.retweets + totals.quotes) / total_engagements, 4)
      else
        0.0
      end

    Map.merge(totals, %{
      total_engagements: total_engagements,
      engagement_rate: engagement_rate,
      virality_score: virality_score
    })
  end

  @doc """
  Ranks and extracts the top N tweets sorted by total engagement.
  """
  @spec rank_top_tweets(list(map()), pos_integer()) :: list(map())
  def rank_top_tweets(tweets, limit \\ 5) when is_list(tweets) do
    tweets
    |> Enum.map(fn tweet ->
      metrics = extract_metrics(tweet)
      engagements =
        Map.get(metrics, "like_count", 0) +
        Map.get(metrics, "retweet_count", 0) +
        Map.get(metrics, "reply_count", 0) +
        Map.get(metrics, "quote_count", 0)

      Map.put(tweet, "calculated_engagement", engagements)
    end)
    |> Enum.sort_by(&Map.get(&1, "calculated_engagement", 0), :desc)
    |> Enum.take(limit)
  end

  @doc """
  Fetches recent tweets for a user and calculates engagement analytics.
  """
  @spec fetch_and_analyze(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def fetch_and_analyze(user_id, opts \\ %{}) do
    params = %{
      "tweet.fields" => "public_metrics,non_public_metrics,organic_metrics,created_at,text",
      "max_results" => Map.get(opts, :limit, 20)
    }

    req_opts = Map.put(opts, :params, params)

    case Client.request(:get, "/users/#{user_id}/tweets", req_opts) do
      {:ok, %{"data" => tweets}} when is_list(tweets) ->
        analytics = aggregate_metrics(tweets)
        top_tweets = rank_top_tweets(tweets, 5)

        {:ok,
         %{
           tweet_count: length(tweets),
           metrics: analytics,
           top_tweets: top_tweets
         }}

      {:ok, %{"meta" => %{"result_count" => 0}}} ->
        {:ok,
         %{
           tweet_count: 0,
           metrics: aggregate_metrics([]),
           top_tweets: []
         }}

      {:ok, other} ->
        {:ok, other}

      error ->
        error
    end
  end

  defp extract_metrics(tweet) do
    cond do
      m = tweet["public_metrics"] -> m
      m = tweet[:public_metrics] -> m
      m = tweet["metrics"] -> m
      m = tweet[:metrics] -> m
      true -> tweet
    end
  end
end
