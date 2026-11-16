defmodule Lux.Lenses.Twitter.Tweets.SearchTweets do
  @moduledoc """
  A lens for searching recent tweets via the Twitter API v2 (`/2/tweets/search/recent`).

  ## Examples

      iex> SearchTweets.focus(%{"query" => "elixir lang", "max_results" => 10})
      {:ok, %{
        tweets: [%{id: "100", text: "Elixir is awesome"}],
        result_count: 1
      }}
  """

  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Search Recent Tweets",
    description: "Searches recent tweets matching a query string via Twitter API v2",
    url: "https://api.twitter.com/2/tweets/search/recent",
    method: :get,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    schema: %{
      type: :object,
      properties: %{
        query: %{
          type: :string,
          description: "One query for matching tweets (up to 512 characters)"
        },
        max_results: %{
          type: :integer,
          description: "Maximum number of search results to return (10 to 100)"
        },
        tweet_fields: %{
          type: :string,
          description: "Comma-separated list of tweet fields to expand (e.g. 'created_at,public_metrics')"
        }
      },
      required: ["query"]
    }

  @impl true
  def after_focus(%{"data" => tweets, "meta" => meta}) when is_list(tweets) do
    {:ok,
     %{
       tweets:
         Enum.map(tweets, fn t ->
           %{
             id: t["id"],
             text: t["text"],
             author_id: t["author_id"],
             created_at: t["created_at"],
             public_metrics: t["public_metrics"]
           }
         end),
       result_count: Map.get(meta, "result_count", length(tweets)),
       next_token: Map.get(meta, "next_token")
     }}
  end

  def after_focus(%{"meta" => %{"result_count" => 0}}) do
    {:ok, %{tweets: [], result_count: 0, next_token: nil}}
  end

  def after_focus(%{"errors" => errors}) do
    {:error, %{"errors" => errors}}
  end

  def after_focus(error) do
    {:error, error}
  end
end
