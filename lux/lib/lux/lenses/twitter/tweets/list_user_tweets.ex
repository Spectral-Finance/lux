defmodule Lux.Lenses.Twitter.Tweets.ListUserTweets do
  @moduledoc """
  A lens for listing tweets from a specific user's timeline via Twitter API v2.

  This lens provides access to a user's tweet timeline with:
  - Pagination support (next_token, max_results)
  - Time range filtering (start_time, end_time)
  - Tweet field expansion support
  - Exclusion of retweets and/or replies

  ## Authentication

  Uses OAuth 2.0 Bearer Token (app-only auth).

  ## Rate Limits

  1,500 requests per 15 minutes (app-level), 900 requests per 15 minutes (user-level).

  ## Examples

      iex> ListUserTweets.focus(%{
      ...>   user_id: "123456789"
      ...> })
      {:ok, %{
        data: [
          %{id: "...", text: "Tweet 1"},
          %{id: "...", text: "Tweet 2"}
        ],
        meta: %{next_token: "...", result_count: 10}
      }}

      iex> ListUserTweets.focus(%{
      ...>   user_id: "123456789",
      ...>   max_results: 5,
      ...>   exclude: "retweets,replies",
      ...>   tweet_fields: "public_metrics,created_at"
      ...> })
  """

  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "List User Tweets",
    description: "Lists tweets from a user's timeline via Twitter API v2",
    url: "https://api.twitter.com/2/users/:user_id/tweets",
    method: :get,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    schema: %{
      type: :object,
      properties: %{
        user_id: %{
          type: :string,
          description: "The unique identifier of the user whose tweets to retrieve",
          pattern: "^[0-9]+$"
        },
        max_results: %{
          type: :integer,
          description: "Maximum number of tweets to return (5-100)",
          minimum: 5,
          maximum: 100,
          default: 10
        },
        pagination_token: %{
          type: :string,
          description: "Token for pagination (from previous response meta.next_token)"
        },
        start_time: %{
          type: :string,
          description: "Earliest tweet creation time (ISO 8601 UTC, e.g. 2021-01-01T00:00:00Z)"
        },
        end_time: %{
          type: :string,
          description: "Latest tweet creation time (ISO 8601 UTC)"
        },
        exclude: %{
          type: :string,
          description: "Comma-separated types to exclude: retweets, replies"
        },
        tweet_fields: %{
          type: :string,
          description:
            "Comma-separated list of tweet fields to include (e.g. created_at,public_metrics,author_id)"
        },
        expansions: %{
          type: :string,
          description:
            "Comma-separated list of expansions (e.g. author_id,attachments.media_keys)"
        }
      },
      required: ["user_id"]
    }

  @doc """
  Transforms the Twitter API response into a simplified format.

  ## Examples

      iex> after_focus(%{
      ...>   "data" => [%{"id" => "123", "text" => "Hello!"}],
      ...>   "meta" => %{"result_count" => 1, "next_token" => "abc123"}
      ...> })
      {:ok, %{
        data: [%{id: "123", text: "Hello!"}],
        meta: %{result_count: 1, next_token: "abc123"}
      }}
  """
  @impl true
  def after_focus(%{"data" => tweets, "meta" => meta}) do
    {:ok, %{
      data: Enum.map(tweets, &transform_tweet/1),
      meta: transform_meta(meta)
    }}
  end

  def after_focus(%{"data" => tweets}) do
    {:ok, %{data: Enum.map(tweets, &transform_tweet/1), meta: %{}}}
  end

  def after_focus(%{"errors" => [%{"title" => title, "detail" => detail} | _]}) do
    {:error, %{title: title, detail: detail}}
  end

  def after_focus(%{"title" => title, "detail" => detail}) do
    {:error, %{title: title, detail: detail}}
  end

  def after_focus(response) do
    {:error, %{title: "Unexpected response", detail: inspect(response)}}
  end

  defp transform_tweet(data) do
    base = %{id: data["id"], text: data["text"]}

    base
    |> maybe_add(:author_id, data["author_id"])
    |> maybe_add(:created_at, data["created_at"])
    |> maybe_add(:conversation_id, data["conversation_id"])
    |> maybe_add(:public_metrics, transform_metrics(data["public_metrics"]))
    |> maybe_add(:referenced_tweets, data["referenced_tweets"])
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
