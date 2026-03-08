defmodule Lux.Lenses.Twitter.SearchTweets do
  @moduledoc """
  Lens for searching recent tweets via Twitter API v2.

  Uses the recent search endpoint (last 7 days for standard access).

  ## Examples

      iex> SearchTweets.focus(%{query: "from:elikirf -is:retweet"})
      {:ok, %{tweets: [...], count: 10, next_token: "..."}}
  """

  use Lux.Lens,
    name: "Search Tweets",
    description: "Searches recent tweets via Twitter API v2",
    url: "https://api.twitter.com/2/tweets/search/recent",
    method: :get,
    headers: [{"Content-Type", "application/json"}],
    auth: %{
      type: :custom,
      auth_function: &Lux.Integrations.Twitter.add_auth_header/1
    },
    schema: %{
      type: :object,
      properties: %{
        query: %{type: :string, description: "Search query (Twitter search operators supported)"},
        max_results: %{type: :integer, description: "Results per page (10-100)", default: 10},
        next_token: %{type: :string, description: "Pagination token"},
        sort_order: %{type: :string, description: "recency or relevancy", default: "recency"}
      },
      required: ["query"]
    }

  alias Lux.Integrations.Twitter.Client

  @default_tweet_fields "id,text,author_id,created_at,public_metrics,lang"

  @impl true
  def before_focus(params) do
    query = params[:query] || params["query"]

    query_params = %{
      "query" => query,
      "max_results" => params[:max_results] || params["max_results"] || 10,
      "tweet.fields" => @default_tweet_fields,
      "sort_order" => params[:sort_order] || params["sort_order"] || "recency"
    }

    query_params =
      if token = params[:next_token] || params["next_token"],
        do: Map.put(query_params, "next_token", token),
        else: query_params

    %{params: query_params}
  end

  @impl true
  def after_focus(%{"data" => tweets, "meta" => meta}) do
    formatted = Enum.map(tweets, &format_tweet/1)

    {:ok, %{
      tweets: formatted,
      count: meta["result_count"] || length(formatted),
      next_token: meta["next_token"],
      newest_id: meta["newest_id"],
      oldest_id: meta["oldest_id"]
    }}
  end

  def after_focus(%{"meta" => %{"result_count" => 0}}) do
    {:ok, %{tweets: [], count: 0, next_token: nil}}
  end

  def after_focus(%{"errors" => [%{"detail" => detail} | _]}) do
    {:error, detail}
  end

  def after_focus(other), do: {:error, "Unexpected response: #{inspect(other)}"}

  defp format_tweet(data) do
    metrics = data["public_metrics"] || %{}

    %{
      id: data["id"],
      text: data["text"],
      author_id: data["author_id"],
      created_at: data["created_at"],
      language: data["lang"],
      metrics: %{
        likes: metrics["like_count"] || 0,
        retweets: metrics["retweet_count"] || 0,
        replies: metrics["reply_count"] || 0
      }
    }
  end
end
