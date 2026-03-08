defmodule Lux.Lenses.Twitter.GetMentions do
  @moduledoc """
  Lens for fetching tweets mentioning a user via Twitter API v2.
  """

  alias Lux.Integrations.Twitter.Client

  @default_tweet_fields "id,text,author_id,created_at,public_metrics"

  def focus(params, _opts \\ []) do
    user_id = params[:user_id] || params["user_id"]

    query_params = %{
      "max_results" => to_string(params[:max_results] || 10),
      "tweet.fields" => @default_tweet_fields
    }

    case Client.request(:get, "/users/#{user_id}/mentions", %{params: query_params}) do
      {:ok, %{data: tweets, meta: meta}} when is_list(tweets) ->
        formatted = Enum.map(tweets, fn t ->
          %{id: t["id"], text: t["text"], author_id: t["author_id"], created_at: t["created_at"]}
        end)
        {:ok, %{mentions: formatted, count: meta["result_count"], next_token: meta["next_token"]}}

      {:ok, %{data: nil, meta: %{"result_count" => 0}}} ->
        {:ok, %{mentions: [], count: 0, next_token: nil}}

      {:error, error} ->
        {:error, error}
    end
  end
end
