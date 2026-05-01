defmodule Lux.Lenses.Twitter.Analytics.TweetMetrics do
  @moduledoc """
  Lens for retrieving tweet engagement metrics from the Twitter/X API v2.

  Fetches comprehensive engagement data for specific tweets including
  likes, retweets, replies, quotes, bookmarks, and impressions.

  ## Examples

      iex> TweetMetrics.focus(%{tweet_ids: "1460323737085691904"})
      {:ok, %{metrics: [%{tweet_id: "1460323737085691904", likes: 100, retweets: 50, ...}]}}

      iex> TweetMetrics.focus(%{tweet_ids: "1460323737085691904,1460323737085691905"})
      {:ok, %{metrics: [%{tweet_id: "...", ...}, %{tweet_id: "...", ...}]}}
  """

  use Lux.Lens,
    name: "Twitter Tweet Engagement Metrics",
    description: "Retrieves engagement metrics (likes, retweets, replies, quotes, bookmarks, impressions) for specified tweets",
    url: "https://api.twitter.com/2/tweets",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        tweet_ids: %{
          type: :string,
          description: "Comma-separated list of tweet IDs (up to 100)"
        },
        metrics: %{
          type: :string,
          description: "Comma-separated list of metrics to retrieve (public_metrics,non_public_metrics,organic_metrics,promoted_metrics)",
          enum: ["public_metrics", "non_public_metrics", "organic_metrics", "promoted_metrics", "public_metrics,non_public_metrics"]
        }
      },
      required: ["tweet_ids"]
    }

  alias Lux.Integrations.Twitter

  def before_focus(params) do
    tweet_ids = Map.get(params, :tweet_ids, "")
    metrics = Map.get(params, :metrics, "public_metrics")

    params
    |> Map.put(:ids, tweet_ids)
    |> Map.put(:tweet.fields, metrics)
    |> Map.delete(:tweet_ids)
    |> Map.delete(:metrics)
  end

  def after_focus(%{"data" => tweets}) do
    metrics = Enum.map(tweets, fn tweet ->
      public_metrics = Map.get(tweet, "public_metrics", %{})

      %{
        tweet_id: tweet["id"],
        text: Map.get(tweet, "text", ""),
        likes: Map.get(public_metrics, "like_count", 0),
        retweets: Map.get(public_metrics, "retweet_count", 0),
        replies: Map.get(public_metrics, "reply_count", 0),
        quotes: Map.get(public_metrics, "quote_count", 0),
        bookmarks: Map.get(public_metrics, "bookmark_count", 0),
        impressions: Map.get(public_metrics, "impression_count", 0)
      }
    end)

    {:ok, %{metrics: metrics, count: length(metrics)}}
  end

  def after_focus(%{"errors" => errors}) do
    Twitter.parse_error(%{"errors" => errors})
  end

  def after_focus(body), do: {:ok, body}
end
