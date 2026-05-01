defmodule Lux.Lenses.Twitter.Monitoring.MentionSentiment do
  @moduledoc """
  Lens for monitoring mentions and performing sentiment analysis via the Twitter/X API v2.

  Searches for mentions of specified users, keywords, or hashtags and returns
  structured data suitable for sentiment analysis pipelines.

  ## Examples

      iex> MentionSentiment.focus(%{query: "@TwitterDev", max_results: 50})
      {:ok, %{mentions: [...], count: 50, query: "@TwitterDev"}}
  """

  use Lux.Lens,
    name: "Twitter Mention & Sentiment Monitor",
    description: "Monitors mentions and retrieves tweet data for sentiment analysis of brand/person mentions",
    url: "https://api.twitter.com/2/tweets/search/recent",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        query: %{
          type: :string,
          description: "Search query for mentions (e.g., '@brand' or 'brand name')"
        },
        max_results: %{
          type: :integer,
          description: "Maximum number of results to return (10-100, default 50)",
          minimum: 10,
          maximum: 100
        },
        sort_order: %{
          type: :string,
          description: "Order of results by recency or relevancy",
          enum: ["recency", "relevancy"]
        },
        start_time: %{
          type: :string,
          description: "Start time in ISO 8601 format"
        },
        end_time: %{
          type: :string,
          description: "End time in ISO 8601 format"
        }
      },
      required: ["query"]
    }

  alias Lux.Integrations.Twitter

  def before_focus(params) do
    params
    |> Map.put_new(:max_results, 50)
    |> Map.put_new(:sort_order, "recency")
    |> Map.put(:"tweet.fields", "created_at,public_metrics,author_id,lang,possibly_sensitive,entities")
    |> Map.put(:"user.fields", "username,name,verified,public_metrics")
    |> maybe_add_time_range()
  end

  def after_focus(%{"data" => tweets, "meta" => meta}) do
    mentions = Enum.map(tweets, fn tweet ->
      metrics = Map.get(tweet, "public_metrics", %{})
      entities = Map.get(tweet, "entities", %{})

      %{
        tweet_id: tweet["id"],
        text: Map.get(tweet, "text", ""),
        author_id: Map.get(tweet, "author_id", ""),
        created_at: Map.get(tweet, "created_at", ""),
        language: Map.get(tweet, "lang", ""),
        possibly_sensitive: Map.get(tweet, "possibly_sensitive", false),
        engagement: %{
          likes: Map.get(metrics, "like_count", 0),
          retweets: Map.get(metrics, "retweet_count", 0),
          replies: Map.get(metrics, "reply_count", 0),
          quotes: Map.get(metrics, "quote_count", 0),
          impressions: Map.get(metrics, "impression_count", 0)
        },
        hashtags: extract_hashtags(entities),
        mentions: extract_mentions(entities),
        urls: extract_urls(entities)
      }
    end)

    {:ok, %{
      mentions: mentions,
      count: length(mentions),
      query: Map.get(meta, "query", ""),
      newest_id: Map.get(meta, "newest_tweet_id"),
      oldest_id: Map.get(meta, "oldest_tweet_id"),
      next_token: Map.get(meta, "next_token")
    }}
  end

  def after_focus(%{"meta" => %{"result_count" => 0}}) do
    {:ok, %{mentions: [], count: 0, message: "No mentions found for this query"}}
  end

  def after_focus(%{"errors" => errors}) do
    Twitter.parse_error(%{"errors" => errors})
  end

  def after_focus(body), do: {:ok, body}

  defp extract_hashtags(%{"hashtags" => hashtags}) do
    Enum.map(hashtags, & &1["tag"])
  end
  defp extract_hashtags(_), do: []

  defp extract_mentions(%{"mentions" => mentions}) do
    Enum.map(mentions, fn m -> %{username: m["username"], user_id: m["id"]} end)
  end
  defp extract_mentions(_), do: []

  defp extract_urls(%{"urls" => urls}) do
    Enum.map(urls, fn u -> %{url: u["expanded_url"], title: Map.get(u, "title", "")} end)
  end
  defp extract_urls(_), do: []

  defp maybe_add_time_range(params) do
    params
    |> maybe_add_start_time()
    |> maybe_add_end_time()
  end

  defp maybe_add_start_time(params) do
    if Map.has_key?(params, :start_time) do
      params
    else
      start_time = DateTime.utc_now() |> DateTime.add(-1, :day) |> DateTime.to_iso8601()
      Map.put(params, :start_time, start_time)
    end
  end

  defp maybe_add_end_time(params) do
    if Map.has_key?(params, :end_time) do
      params
    else
      Map.put(params, :end_time, DateTime.utc_now() |> DateTime.to_iso8601())
    end
  end
end
