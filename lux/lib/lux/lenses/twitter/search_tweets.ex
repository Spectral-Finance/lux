defmodule Lux.Lenses.Twitter.SearchTweets do
  @moduledoc """
  Lens for searching recent tweets via Twitter API v2.

  Uses the recent search endpoint (last 7 days for standard access).

  ## Examples

      iex> SearchTweets.focus(%{query: "from:elixir -is:retweet"})
      {:ok, %{tweets: [...], count: 10, next_token: "..."}}
  """

  alias Lux.Integrations.Twitter.Client

  @default_tweet_fields "id,text,author_id,created_at,public_metrics,lang"

  def focus(params, _opts \\ []) do
    query = params[:query] || params["query"]

    query_params = %{
      "query" => query,
      "max_results" => to_string(params[:max_results] || 10),
      "tweet.fields" => @default_tweet_fields,
      "sort_order" => params[:sort_order] || "recency"
    }

    query_params =
      if token = params[:next_token],
        do: Map.put(query_params, "next_token", token),
        else: query_params

    case Client.request(:get, "/tweets/search/recent", %{params: query_params}) do
      {:ok, %{data: tweets, meta: meta}} when is_list(tweets) ->
        formatted = Enum.map(tweets, &format_tweet/1)
        {:ok, %{
          tweets: formatted,
          count: meta["result_count"] || length(formatted),
          next_token: meta["next_token"],
          newest_id: meta["newest_id"],
          oldest_id: meta["oldest_id"]
        }}

      {:ok, %{data: nil, meta: %{"result_count" => 0}}} ->
        {:ok, %{tweets: [], count: 0, next_token: nil}}

      {:ok, %{data: data}} ->
        {:error, "Unexpected response: #{inspect(data)}"}

      {:error, error} ->
        {:error, error}
    end
  end

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
