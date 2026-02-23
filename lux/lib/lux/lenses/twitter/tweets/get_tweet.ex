defmodule Lux.Lenses.Twitter.Tweets.GetTweet do
  @moduledoc """
  A lens for retrieving a single tweet by ID from the Twitter API v2.

  This lens provides a simple interface for fetching tweet details with:
  - Minimal required parameters (tweet_id)
  - Optional field expansion support (author_id, created_at, public_metrics, etc.)
  - Direct Twitter API error propagation
  - Clean response structure

  ## Authentication

  Uses OAuth 2.0 Bearer Token (app-only auth). Configure in application config:

      config :lux, :api_keys, twitter: "your_bearer_token"

  ## Rate Limits

  300 requests per 15 minutes (app-level), 900 requests per 15 minutes (user-level).

  ## Examples

      iex> GetTweet.focus(%{
      ...>   tweet_id: "1234567890123456789"
      ...> })
      {:ok, %{
        id: "1234567890123456789",
        text: "Hello, world!",
        author_id: "123456789",
        created_at: "2024-01-01T00:00:00.000Z"
      }}

      iex> GetTweet.focus(%{
      ...>   tweet_id: "1234567890123456789",
      ...>   tweet_fields: "public_metrics,created_at,author_id"
      ...> })
      {:ok, %{
        id: "1234567890123456789",
        text: "Hello, world!",
        public_metrics: %{
          retweet_count: 10,
          reply_count: 5,
          like_count: 100,
          quote_count: 2
        }
      }}
  """

  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Get Tweet",
    description: "Retrieves a single tweet by ID from the Twitter API v2",
    url: "https://api.twitter.com/2/tweets/:tweet_id",
    method: :get,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    schema: %{
      type: :object,
      properties: %{
        tweet_id: %{
          type: :string,
          description: "The unique identifier of the tweet to retrieve",
          pattern: "^[0-9]+$"
        },
        tweet_fields: %{
          type: :string,
          description:
            "Comma-separated list of tweet fields to include. Available: attachments, author_id, context_annotations, conversation_id, created_at, edit_controls, entities, geo, id, in_reply_to_user_id, lang, non_public_metrics, organic_metrics, possibly_sensitive, promoted_metrics, public_metrics, referenced_tweets, reply_settings, source, text, withheld",
          default: "id,text,author_id,created_at"
        },
        expansions: %{
          type: :string,
          description:
            "Comma-separated list of expansions. Available: attachments.media_keys, attachments.poll_ids, author_id, edit_history_tweet_ids, entities.mentions.username, geo.place_id, in_reply_to_user_id, referenced_tweets.id, referenced_tweets.id.author_id"
        },
        user_fields: %{
          type: :string,
          description:
            "Comma-separated list of user fields to include when author_id expansion is requested"
        }
      },
      required: ["tweet_id"]
    }

  @doc """
  Transforms the Twitter API response into a simplified format.

  ## Examples

      iex> after_focus(%{
      ...>   "data" => %{
      ...>     "id" => "1234567890",
      ...>     "text" => "Hello, world!",
      ...>     "author_id" => "987654321",
      ...>     "created_at" => "2024-01-01T00:00:00.000Z"
      ...>   }
      ...> })
      {:ok, %{
        id: "1234567890",
        text: "Hello, world!",
        author_id: "987654321",
        created_at: "2024-01-01T00:00:00.000Z"
      }}
  """
  @impl true
  def after_focus(%{"data" => data}) do
    {:ok, transform_tweet(data)}
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
    base = %{
      id: data["id"],
      text: data["text"]
    }

    base
    |> maybe_add(:author_id, data["author_id"])
    |> maybe_add(:created_at, data["created_at"])
    |> maybe_add(:conversation_id, data["conversation_id"])
    |> maybe_add(:lang, data["lang"])
    |> maybe_add(:possibly_sensitive, data["possibly_sensitive"])
    |> maybe_add(:reply_settings, data["reply_settings"])
    |> maybe_add(:source, data["source"])
    |> maybe_add(:public_metrics, transform_metrics(data["public_metrics"]))
    |> maybe_add(:referenced_tweets, data["referenced_tweets"])
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
