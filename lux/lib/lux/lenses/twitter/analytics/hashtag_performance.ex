defmodule Lux.Lenses.Twitter.Analytics.HashtagPerformance do
  @moduledoc """
  Lens for analyzing hashtag performance and trending topics via the Twitter/X API v2.

  Tracks hashtag usage metrics including tweet volume, engagement rates,
  and reach estimates for specified hashtags or keywords.

  ## Examples

      iex> HashtagPerformance.focus(%{query: "#Elixir", granularity: "day"})
      {:ok, %{trends: [%{start: "2024-01-01T00:00:00Z", end: "...", tweets: 150}]}}
  """

  use Lux.Lens,
    name: "Twitter Hashtag Performance Analysis",
    description: "Analyzes hashtag usage volume, trends, and engagement over time",
    url: "https://api.twitter.com/2/tweets/counts/recent",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        query: %{
          type: :string,
          description: "Search query (hashtag, keyword, or complex query)"
        },
        granularity: %{
          type: :string,
          description: "Time granularity for tweet count aggregation",
          enum: ["minute", "hour", "day"]
        },
        start_time: %{
          type: :string,
          description: "Start time in ISO 8601 format (default: 30 days ago)"
        },
        end_time: %{
          type: :string,
          description: "End time in ISO 8601 format (default: now)"
        }
      },
      required: ["query"]
    }

  alias Lux.Integrations.Twitter

  def before_focus(params) do
    params
    |> Map.put_new(:granularity, "day")
    |> maybe_add_time_range()
  end

  def after_focus(%{"data" => counts, "meta" => meta}) do
    total = Map.get(meta, "total_tweet_count", 0)

    trends = Enum.map(counts, fn count ->
      %{
        start: Map.get(count, "start", ""),
        end: Map.get(count, "end", ""),
        tweet_count: Map.get(count, "tweet_count", 0)
      }
    end)

    {:ok, %{
      query: Map.get(meta, "query", ""),
      total_tweets: total,
      trends: trends,
      granularity: Map.get(meta, "granularity", "day")
    }}
  end

  def after_focus(%{"meta" => %{"total_tweet_count" => 0}}) do
    {:ok, %{total_tweets: 0, trends: [], message: "No tweets found for this query"}}
  end

  def after_focus(%{"errors" => errors}) do
    Twitter.parse_error(%{"errors" => errors})
  end

  def after_focus(body), do: {:ok, body}

  defp maybe_add_time_range(params) do
    params
    |> maybe_add_start_time()
    |> maybe_add_end_time()
  end

  defp maybe_add_start_time(params) do
    if Map.has_key?(params, :start_time) do
      params
    else
      # Default: 7 days ago
      start_time = DateTime.utc_now() |> DateTime.add(-7, :day) |> DateTime.to_iso8601()
      Map.put(params, :start_time, start_time)
    end
  end

  defp maybe_add_end_time(params) do
    if Map.has_key?(params, :end_time) do
      params
    else
      end_time = DateTime.utc_now() |> DateTime.to_iso8601()
      Map.put(params, :end_time, end_time)
    end
  end
end
