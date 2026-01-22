defmodule Lux.Lenses.Twitter.SearchTweets do
  @moduledoc """
  Lens to search for recent tweets using Twitter API v2.
  """
  
  alias Lux.Integrations.Twitter.Client
  require Logger

  def search(query, max_results \\ 10) do
    Logger.info("Searching tweets for: #{query}")
    
    params = [
      query: query,
      max_results: max_results,
      "tweet.fields": "created_at,author_id,public_metrics,lang"
    ]

    case Client.request(:get, "/tweets/search/recent", params: params) do
      {:ok, %{"data" => tweets}} ->
        {:ok, tweets}
      
      {:ok, %{"meta" => %{"result_count" => 0}}} ->
        {:ok, []}

      error ->
        Logger.error("Search failed: #{inspect(error)}")
        {:error, "Search failed"}
    end
  end
end
