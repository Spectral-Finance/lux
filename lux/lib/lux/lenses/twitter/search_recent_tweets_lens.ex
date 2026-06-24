defmodule Lux.Lenses.Twitter.SearchRecentTweetsLens do
  @moduledoc """
  Lens to search recent tweets based on a query. Useful for hashtag and mentions analysis.
  """
  use Lux.Lens

  alias Lux.Lenses.Twitter.Base, as: TwitterBase

  @impl true
  def name, do: "Twitter Search Recent Tweets Lens"

  @impl true
  def description, do: "Searches recent tweets based on a query string (e.g. hashtag, mentions)."

  @impl true
  def schema do
    %{
      type: :object,
      properties: %{
        query: %{
          type: :string,
          description: "The search query (e.g., #hashtag or @username)."
        },
        max_results: %{
          type: :integer,
          description: "Maximum number of results to return (10-100).",
          default: 10
        }
      },
      required: ["query"]
    }
  end

  @impl true
  def focus(%{"query" => query} = params, _context) do
    client = TwitterBase.client()
    max_results = Map.get(params, "max_results", 10)

    Req.get(client, url: "/tweets/search/recent", params: [
      query: query,
      max_results: max_results,
      "tweet.fields": "public_metrics,created_at,author_id"
    ])
    |> TwitterBase.process_response()
    |> case do
      {:ok, %{"data" => tweets}} ->
        {:ok, tweets}
      {:ok, %{"meta" => %{"result_count" => 0}}} ->
        {:ok, []}
      {:ok, other} ->
        {:error, "Unexpected response format: #{inspect(other)}"}
      {:error, reason} ->
        {:error, reason}
    end
  end
end
