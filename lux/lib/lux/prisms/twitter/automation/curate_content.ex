defmodule Lux.Prisms.Twitter.Automation.CurateContent do
  @moduledoc """
  A prism for curating Twitter content based on configurable filters and rules.

  Enables agents to automatically discover, filter, and organize relevant content
  from Twitter for sharing, engagement, or content calendar population.

  ## Examples

      iex> CurateContent.handler(%{
      ...>   query: "#elixir OR #phoenix lang:en -is:retweet",
      ...>   min_likes: 10,
      ...>   min_retweets: 5,
      ...>   max_results: 20
      ...> }, %{name: "ContentCurator"})
      {:ok, %{curated_tweets: [...], total_found: 20, passed_filters: 8}}
  """

  use Lux.Prism,
    name: "Curate Twitter Content",
    description: "Search and filter tweets by quality metrics for content curation",
    input_schema: %{
      type: :object,
      properties: %{
        query: %{
          type: :string,
          description: "Twitter search query to find content"
        },
        min_likes: %{
          type: :integer,
          description: "Minimum number of likes required",
          minimum: 0
        },
        min_retweets: %{
          type: :integer,
          description: "Minimum number of retweets required",
          minimum: 0
        },
        min_replies: %{
          type: :integer,
          description: "Minimum number of replies required",
          minimum: 0
        },
        max_results: %{
          type: :integer,
          description: "Maximum tweets to search through (10-100)",
          minimum: 10,
          maximum: 100
        },
        exclude_keywords: %{
          type: :array,
          items: %{type: :string},
          description: "Keywords to exclude from curated content"
        }
      },
      required: ["query"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        curated_tweets: %{
          type: :array,
          description: "List of tweets that passed all filters"
        },
        total_found: %{type: :integer, description: "Total tweets found before filtering"},
        passed_filters: %{type: :integer, description: "Number of tweets that passed all filters"},
        query: %{type: :string, description: "The search query used"}
      },
      required: ["curated_tweets", "total_found", "passed_filters"]
    }

  alias Lux.Integrations.Twitter.Client
  require Logger

  @doc """
  Searches for and curates tweets based on quality filters.
  """
  def handler(%{query: query} = params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    max_results = Map.get(params, :max_results, 25)
    Logger.info("Agent #{agent_name} curating content for query: #{query}")

    query_params = %{
      "query" => query,
      "max_results" => max_results,
      "tweet.fields" => "id,text,created_at,author_id,public_metrics,entities"
    }

    case Client.request(:get, "/tweets/search/recent", %{params: query_params}) do
      {:ok, %{"data" => tweets, "meta" => meta}} ->
        curated = apply_filters(tweets, params)
        {:ok, %{
          curated_tweets: Enum.map(curated, &format_tweet/1),
          total_found: meta["result_count"] || length(tweets),
          passed_filters: length(curated),
          query: query
        }}

      {:ok, %{"meta" => %{"result_count" => 0}}} ->
        {:ok, %{curated_tweets: [], total_found: 0, passed_filters: 0, query: query}}

      {:error, error} ->
        Logger.error("Content curation failed: #{inspect(error)}")
        {:error, "Content curation failed: #{inspect(error)}"}
    end
  end

  def handler(_params, _agent), do: {:error, "Missing required parameter: query"}

  defp apply_filters(tweets, params) do
    min_likes = Map.get(params, :min_likes, 0)
    min_retweets = Map.get(params, :min_retweets, 0)
    min_replies = Map.get(params, :min_replies, 0)
    exclude_keywords = Map.get(params, :exclude_keywords, [])

    Enum.filter(tweets, fn tweet ->
      metrics = tweet["public_metrics"] || %{}
      text = tweet["text"] || ""

      meets_like_threshold?(metrics, min_likes) and
      meets_retweet_threshold?(metrics, min_retweets) and
      meets_reply_threshold?(metrics, min_replies) and
      not contains_excluded_keywords?(text, exclude_keywords)
    end)
  end

  defp meets_like_threshold?(metrics, min), do: (metrics["like_count"] || 0) >= min
  defp meets_retweet_threshold?(metrics, min), do: (metrics["retweet_count"] || 0) >= min
  defp meets_reply_threshold?(metrics, min), do: (metrics["reply_count"] || 0) >= min

  defp contains_excluded_keywords?(_text, []), do: false
  defp contains_excluded_keywords?(text, keywords) do
    lower_text = String.downcase(text)
    Enum.any?(keywords, fn kw -> String.contains?(lower_text, String.downcase(kw)) end)
  end

  defp format_tweet(tweet) do
    %{
      id: tweet["id"],
      text: tweet["text"],
      created_at: tweet["created_at"],
      author_id: tweet["author_id"],
      metrics: tweet["public_metrics"] || %{},
      entities: tweet["entities"] || %{}
    }
  end
end
