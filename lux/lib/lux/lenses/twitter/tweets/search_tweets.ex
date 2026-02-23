defmodule Lux.Lenses.Twitter.Tweets.SearchTweets do
  @moduledoc """
  A lens for searching recent tweets via Twitter API v2.

  Searches tweets from the last 7 days matching a query string.
  Supports full Twitter query syntax including operators for filtering
  by author, language, media type, engagement metrics, and more.

  ## Authentication

  Uses OAuth 2.0 Bearer Token (app-only auth).

  ## Rate Limits

  450 requests per 15 minutes (app-level), 180 requests per 15 minutes (user-level).

  ## Query Operators

  - `from:username` - Tweets from a specific user
  - `to:username` - Replies to a specific user
  - `#hashtag` - Tweets containing a hashtag
  - `has:media` - Tweets with media attached
  - `lang:en` - Tweets in a specific language
  - `-is:retweet` - Exclude retweets

  ## Examples

      iex> SearchTweets.focus(%{
      ...>   query: "Elixir programming -is:retweet lang:en"
      ...> })
      {:ok, %{
        data: [%{id: "...", text: "..."}],
        meta: %{result_count: 10, newest_id: "...", oldest_id: "..."}
      }}

      iex> SearchTweets.focus(%{
      ...>   query: "from:elixirlang",
      ...>   max_results: 20,
      ...>   tweet_fields: "public_metrics,created_at"
      ...> })
  """

  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Search Recent Tweets",
    description: "Searches recent tweets (last 7 days) matching a query via Twitter API v2",
    url: "https://api.twitter.com/2/tweets/search/recent",
    method: :get,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    schema: %{
      type: :object,
      properties: %{
        query: %{
          type: :string,
          description:
            "The search query string (max 512 chars). Supports full Twitter query syntax.",
          min_length: 1,
          max_length: 512
        },
        max_results: %{
          type: :integer,
          description: "Maximum number of results (10-100)",
          minimum: 10,
          maximum: 100,
          default: 10
        },
        next_token: %{
          type: :string,
          description: "Pagination token from previous response meta.next_token"
        },
        start_time: %{
          type: :string,
          description:
            "Earliest tweet creation time in ISO 8601 UTC (within last 7 days)"
        },
        end_time: %{
          type: :string,
          description: "Latest tweet creation time in ISO 8601 UTC"
        },
        tweet_fields: %{
          type: :string,
          description:
            "Comma-separated tweet fields to include (e.g. created_at,author_id,public_metrics)"
        },
        expansions: %{
          type: :string,
          description: "Comma-separated expansions (e.g. author_id,attachments.media_keys)"
        },
        sort_order: %{
          type: :string,
          description: "Sort order for results: recency (default) or relevancy",
          enum: ["recency", "relevancy"]
        }
      },
      required: ["query"]
    }

  @doc """
  Transforms the Twitter API search response into a simplified format.

  ## Examples

      iex> after_focus(%{
      ...>   "data" => [%{"id" => "123", "text" => "Elixir is great!"}],
      ...>   "meta" => %{"result_count" => 1, "newest_id" => "123", "oldest_id" => "123"}
      ...> })
      {:ok, %{
        data: [%{id: "123", text: "Elixir is great!"}],
        meta: %{result_count: 1, newest_id: "123", oldest_id: "123"}
      }}
  """
  @impl true
  def after_focus(%{"data" => tweets, "meta" => meta}) do
    {:ok, %{
      data: Enum.map(tweets, &transform_tweet/1),
      meta: transform_meta(meta)
    }}
  end

  def after_focus(%{"meta" => %{"result_count" => 0} = meta}) do
    {:ok, %{data: [], meta: transform_meta(meta)}}
  end

  def after_focus(%{"errors" => [%{"title" => title, "detail" => detail} | _]}) do
    {:error, %{title: title, detail: detail}}
  end

  def after_focus(%{"title" => "Invalid Request", "detail" => detail}) do
    {:error, %{title: "Invalid Request", detail: detail}}
  end

  def after_focus(response) do
    {:error, %{title: "Unexpected response", detail: inspect(response)}}
  end

  defp transform_tweet(data) do
    %{id: data["id"], text: data["text"]}
    |> maybe_add(:author_id, data["author_id"])
    |> maybe_add(:created_at, data["created_at"])
    |> maybe_add(:conversation_id, data["conversation_id"])
    |> maybe_add(:lang, data["lang"])
    |> maybe_add(:possibly_sensitive, data["possibly_sensitive"])
    |> maybe_add(:public_metrics, transform_metrics(data["public_metrics"]))
  end

  defp transform_meta(meta) do
    %{}
    |> maybe_add(:result_count, meta["result_count"])
    |> maybe_add(:next_token, meta["next_token"])
    |> maybe_add(:previous_token, meta["previous_token"])
    |> maybe_add(:newest_id, meta["newest_id"])
    |> maybe_add(:oldest_id, meta["oldest_id"])
  end

  defp transform_metrics(nil), do: nil

  defp transform_metrics(metrics) do
    %{
      retweet_count: metrics["retweet_count"],
      reply_count: metrics["reply_count"],
      like_count: metrics["like_count"],
      quote_count: metrics["quote_count"],
      bookmark_count: metrics["bookmark_count"],
      impression_count: metrics["impression_count"]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp maybe_add(map, _key, nil), do: map
  defp maybe_add(map, key, value), do: Map.put(map, key, value)
end
