defmodule Lux.Lenses.Twitter.Analytics.GetTweetMetrics do
  @moduledoc """
  A lens for fetching Twitter/X tweet engagement metrics.

  Retrieves public metrics (impressions, likes, retweets, replies, quotes)
  and optionally non-public metrics (clicks, profile visits) via
  Twitter API v2 with OAuth2 Bearer token auth.

  ## Examples

      iex> GetTweetMetrics.focus(%{
      ...>   tweet_id: "1234567890123456789",
      ...>   bearer_token: "AAAA..."
      ...> })
      {:ok, %{
        tweet_id: "...",
        text: "...",
        public_metrics: %{impression_count: N, like_count: N, ...}
      }}
  """

  require Logger

  @base_url "https://api.twitter.com/2"

  use Lux.Lens,
    name: "Get Twitter Tweet Metrics",
    description: "Fetches engagement metrics for a tweet via Twitter API v2",
    url: @base_url,
    method: :get,
    headers: [{"Accept", "application/json"}],
    schema: %{
      type: :object,
      properties: %{
        tweet_id: %{type: :string, description: "Tweet ID"},
        bearer_token: %{type: :string, description: "Twitter API Bearer token"},
        include_non_public: %{
          type: :boolean,
          description: "Include non-public metrics (requires elevated access)",
          default: false
        }
      },
      required: ["tweet_id", "bearer_token"]
    }

  @impl true
  def focus(%{tweet_id: tweet_id, bearer_token: token} = params) do
    metric_fields = if Map.get(params, :include_non_public, false) do
      "public_metrics,non_public_metrics,organic_metrics"
    else
      "public_metrics"
    end

    url     = @base_url <> "/tweets/#{tweet_id}"
    headers = [{"Authorization", "Bearer #{token}"}, {"Accept", "application/json"}]
    query   = %{"tweet.fields" => "#{metric_fields},created_at,author_id,text"}

    case Req.get(url, params: query, headers: headers, receive_timeout: 15_000) do
      {:ok, %{status: 200, body: %{"data" => tweet}}} ->
        result = %{
          tweet_id:        tweet["id"],
          text:            tweet["text"],
          author_id:       tweet["author_id"],
          created_at:      tweet["created_at"],
          public_metrics:  atomize(tweet["public_metrics"] || %{}),
          non_public_metrics: atomize(tweet["non_public_metrics"] || %{}),
          organic_metrics: atomize(tweet["organic_metrics"] || %{})
        }
        Logger.info("Fetched metrics for tweet #{tweet_id}: #{inspect(result.public_metrics)}")
        {:ok, result}

      {:ok, %{status: 401}} -> {:error, :invalid_bearer_token}
      {:ok, %{status: 403}} -> {:error, :insufficient_access_level}
      {:ok, %{status: 404}} -> {:error, :tweet_not_found}
      {:ok, %{status: 429}} -> {:error, :rate_limited}
      {:ok, %{status: s, body: b}} -> {:error, {s, b}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp atomize(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {String.to_atom(k), v} end)
  end
  defp atomize(v), do: v
end
