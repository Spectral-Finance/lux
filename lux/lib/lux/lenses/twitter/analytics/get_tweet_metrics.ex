defmodule Lux.Lenses.Twitter.Analytics.GetTweetMetrics do
  @moduledoc """
  A lens for retrieving detailed engagement metrics for a tweet.

  Fetches public and engagement metrics including impressions, likes,
  retweets, replies, quotes, and bookmarks via Twitter API v2.

  ## Authentication

  Uses OAuth 2.0 Bearer Token. Configure in application config:

      config :lux, :api_keys, twitter: "your_bearer_token"

  ## Rate Limits

  300 requests per 15 minutes (app-level).

  ## Examples

      iex> GetTweetMetrics.focus(%{tweet_id: "1234567890"})
      {:ok, %{
        tweet_id: "1234567890",
        text: "Hello world",
        metrics: %{
          like_count: 150,
          retweet_count: 42,
          reply_count: 28,
          quote_count: 12,
          impression_count: 5000,
          bookmark_count: 30
        },
        engagement_rate: 4.64
      }}

      iex> GetTweetMetrics.focus(%{tweet_id: "999"})
      {:error, %{title: "Not Found Error", detail: "Could not find tweet with id: [999]."}}
  """

  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Get Tweet Metrics",
    description: "Retrieves detailed engagement metrics for a tweet including impressions, likes, retweets, and engagement rate",
    url: "https://api.twitter.com/2/tweets/:tweet_id",
    method: :get,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    schema: %{
      type: :object,
      properties: %{
        tweet_id: %{
          type: :string,
          description: "The unique identifier of the tweet",
          pattern: "^[0-9]+"
        },
        tweet_fields: %{
          type: :string,
          description: "Additional tweet fields to include",
          default: "public_metrics,non_public_metrics,created_at,author_id"
        }
      },
      required: ["tweet_id"]
    }

  @impl true
  def before_focus(%{tweet_id: tweet_id} = params) do
    fields = Map.get(params, :tweet_fields, "public_metrics,created_at,author_id")

    {:ok, %{
      "tweet.fields" => fields,
      tweet_id: tweet_id
    }}
  end

  def before_focus(%{"tweet_id" => tweet_id} = params) do
    before_focus(%{tweet_id: tweet_id, tweet_fields: params["tweet_fields"]})
  end

  @impl true
  def after_focus(%{"data" => data}) do
    metrics = data["public_metrics"] || %{}
    total_engagement = calculate_engagement(metrics)
    impression_count = metrics["impression_count"] || 0
    engagement_rate = if impression_count > 0, do: Float.round(total_engagement / impression_count * 100, 2), else: 0.0

    {:ok, %{
      tweet_id: data["id"],
      text: data["text"],
      author_id: data["author_id"],
      created_at: data["created_at"],
      metrics: %{
        like_count: metrics["like_count"] || 0,
        retweet_count: metrics["retweet_count"] || 0,
        reply_count: metrics["reply_count"] || 0,
        quote_count: metrics["quote_count"] || 0,
        impression_count: impression_count,
        bookmark_count: metrics["bookmark_count"] || 0
      },
      engagement_rate: engagement_rate,
      total_engagement: total_engagement
    }}
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

  defp calculate_engagement(metrics) do
    (metrics["like_count"] || 0) +
    (metrics["retweet_count"] || 0) +
    (metrics["reply_count"] || 0) +
    (metrics["quote_count"] || 0) +
    (metrics["bookmark_count"] || 0)
  end
end
