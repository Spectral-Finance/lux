defmodule Lux.Lenses.Twitter.Tweets.Search do
  @moduledoc """
  Searches for Tweets matching a query.

  ## Examples

      # Basic search
      Lux.Lenses.Twitter.Tweets.Search.focus(%{query: "from:elonmusk"})

      # Advanced search with filters
      Lux.Lenses.Twitter.Tweets.Search.focus(%{
        query: "AI agents lang:en -is:retweet",
        max_results: 20,
        sort_order: "recency"
      })
  """

  use Lux.Lens,
    name: "Twitter / Search Tweets",
    description: "Searches for Tweets matching a query using Twitter API v2 recent search",
    url: "/2/tweets/search/recent",
    method: :get,
    headers: [{"Content-Type", "application/json"}],
    auth: %{type: :custom, auth_function: &Lux.Integrations.Twitter.add_bearer_token/1},
    schema: %{
      type: :object,
      properties: %{
        query: %{type: :string, description: "Search query (max 512 chars). Supports standard Twitter search operators"},
        max_results: %{type: :integer, description: "Results per page (10-100)", default: 10},
        sort_order: %{type: :string, description: "Sort order", enum: ["recency", "relevancy"]},
        start_time: %{type: :string, description: "Oldest timestamp (ISO 8601)"},
        end_time: %{type: :string, description: "Newest timestamp (ISO 8601)"},
        next_token: %{type: :string, description: "Token for the next page"}
      },
      required: ["query"]
    },
    transform: &__MODULE__.transform_response/1

  @doc false
  def transform_response(response) do
    case response do
      %{status: 200, body: %{"data" => tweets}} ->
        meta = Map.get(response.body, "meta", %{})
        {:ok, %{tweets: tweets, meta: meta, result_count: length(tweets)}}

      %{status: status, body: body} ->
        {:error, %{status: status, body: body}}
    end
  end
end
