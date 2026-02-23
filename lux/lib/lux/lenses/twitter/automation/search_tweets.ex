defmodule Lux.Lenses.Twitter.Automation.SearchTweets do
  @moduledoc """
  A lens for searching tweets on Twitter/X for content curation.

  Enables agents to find tweets by keywords, hashtags, or advanced search queries
  for content curation and engagement rule processing.

  ## Examples

      iex> SearchTweets.focus(%{
      ...>   "query" => "#elixir lang:en -is:retweet",
      ...>   "max_results" => 10
      ...> }, %{})
      {:ok, %{tweets: [...], result_count: 10, newest_id: "..."}}
  """

  use Lux.Lens,
    name: "Search Tweets",
    description: "Search Twitter for tweets matching a query for content curation and monitoring",
    schema: %{
      type: :object,
      properties: %{
        query: %{
          type: :string,
          description: "Twitter search query (supports operators like #hashtag, @mention, -is:retweet, lang:en)"
        },
        max_results: %{
          type: :integer,
          description: "Maximum number of results to return (10-100)",
          minimum: 10,
          maximum: 100
        },
        tweet_fields: %{
          type: :array,
          items: %{type: :string},
          description: "Tweet fields to include: id, text, created_at, author_id, public_metrics, etc."
        },
        start_time: %{
          type: :string,
          description: "Oldest UTC timestamp for tweets (ISO 8601 format)"
        },
        end_time: %{
          type: :string,
          description: "Newest UTC timestamp for tweets (ISO 8601 format)"
        },
        next_token: %{
          type: :string,
          description: "Pagination token from previous response"
        }
      },
      required: ["query"]
    }

  alias Lux.Integrations.Twitter.Client
  require Logger

  @default_tweet_fields ["id", "text", "created_at", "author_id", "public_metrics", "entities"]

  defoverridable focus: 2

  @doc """
  Searches Twitter for tweets matching the given query.
  """
  def focus(params, _context) do
    query = params["query"] || params[:query]
    max_results = params["max_results"] || params[:max_results] || 10
    tweet_fields = params["tweet_fields"] || params[:tweet_fields] || @default_tweet_fields

    query_params =
      %{
        "query" => query,
        "max_results" => max_results,
        "tweet.fields" => Enum.join(tweet_fields, ",")
      }
      |> maybe_add_param(params, "start_time")
      |> maybe_add_param(params, "end_time")
      |> maybe_add_param(params, "next_token")

    Logger.info("Searching tweets with query: #{query}")

    case Client.request(:get, "/tweets/search/recent", %{params: query_params}) do
      {:ok, %{"data" => tweets, "meta" => meta}} ->
        {:ok, %{
          tweets: Enum.map(tweets, &format_tweet/1),
          result_count: meta["result_count"] || length(tweets),
          newest_id: meta["newest_id"],
          oldest_id: meta["oldest_id"],
          next_token: meta["next_token"]
        }}

      {:ok, %{"meta" => %{"result_count" => 0}}} ->
        {:ok, %{tweets: [], result_count: 0, newest_id: nil, oldest_id: nil, next_token: nil}}

      {:error, error} ->
        Logger.error("Failed to search tweets: #{inspect(error)}")
        {:error, error}
    end
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

  defp maybe_add_param(params, source, key) do
    val = source[key] || source[String.to_atom(key)]
    case val do
      nil -> params
      value -> Map.put(params, key, value)
    end
  end
end
