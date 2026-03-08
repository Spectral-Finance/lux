defmodule Lux.Lenses.Twitter.GetTimeline do
  @moduledoc """
  Lens for fetching a user's tweet timeline via Twitter API v2.

  ## Examples

      iex> GetTimeline.focus(%{user_id: "123", max_results: 20})
      {:ok, %{tweets: [...], count: 20, next_token: "..."}}
  """

  alias Lux.Integrations.Twitter.Client

  @default_tweet_fields "id,text,author_id,created_at,public_metrics,lang"

  def focus(params, _opts \\ []) do
    user_id = params[:user_id] || params["user_id"]

    query_params = %{
      "max_results" => to_string(params[:max_results] || 10),
      "tweet.fields" => @default_tweet_fields
    }

    query_params =
      if token = params[:next_token],
        do: Map.put(query_params, "pagination_token", token),
        else: query_params

    query_params =
      if exclude = params[:exclude],
        do: Map.put(query_params, "exclude", exclude),
        else: query_params

    case Client.request(:get, "/users/#{user_id}/tweets", %{params: query_params}) do
      {:ok, %{data: tweets, meta: meta}} when is_list(tweets) ->
        formatted = Enum.map(tweets, &format_tweet/1)
        {:ok, %{tweets: formatted, count: meta["result_count"], next_token: meta["next_token"]}}

      {:ok, %{data: nil, meta: %{"result_count" => 0}}} ->
        {:ok, %{tweets: [], count: 0, next_token: nil}}

      {:error, error} ->
        {:error, error}
    end
  end

  defp format_tweet(t) do
    m = t["public_metrics"] || %{}
    %{
      id: t["id"],
      text: t["text"],
      author_id: t["author_id"],
      created_at: t["created_at"],
      metrics: %{
        likes: m["like_count"] || 0,
        retweets: m["retweet_count"] || 0,
        replies: m["reply_count"] || 0
      }
    }
  end
end
