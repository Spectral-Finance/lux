defmodule Lux.Lenses.Twitter.GetTimeline do
  @moduledoc """
  Lens for fetching a user's tweet timeline via Twitter API v2.

  ## Examples

      iex> GetTimeline.focus(%{user_id: "123", max_results: 20})
      {:ok, %{tweets: [...], count: 20, next_token: "..."}}
  """

  use Lux.Lens,
    name: "Get Timeline",
    description: "Fetches a user's tweet timeline",
    url: "https://api.twitter.com/2/users/:id/tweets",
    method: :get,
    headers: [{"Content-Type", "application/json"}],
    auth: %{
      type: :custom,
      auth_function: &Lux.Integrations.Twitter.add_auth_header/1
    },
    schema: %{
      type: :object,
      properties: %{
        user_id: %{type: :string, description: "User ID"},
        max_results: %{type: :integer, description: "Results per page (5-100)", default: 10},
        next_token: %{type: :string, description: "Pagination token"},
        exclude: %{type: :string, description: "Comma-sep: retweets,replies"}
      },
      required: ["user_id"]
    }

  @default_tweet_fields "id,text,author_id,created_at,public_metrics,lang"

  @impl true
  def before_focus(params) do
    user_id = params[:user_id] || params["user_id"]

    query_params = %{
      "max_results" => params[:max_results] || params["max_results"] || 10,
      "tweet.fields" => @default_tweet_fields
    }

    query_params =
      if token = params[:next_token] || params["next_token"],
        do: Map.put(query_params, "pagination_token", token),
        else: query_params

    query_params =
      if exclude = params[:exclude] || params["exclude"],
        do: Map.put(query_params, "exclude", exclude),
        else: query_params

    %{url: "https://api.twitter.com/2/users/#{user_id}/tweets", params: query_params}
  end

  @impl true
  def after_focus(%{"data" => tweets, "meta" => meta}) do
    formatted =
      Enum.map(tweets, fn t ->
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
      end)

    {:ok, %{tweets: formatted, count: meta["result_count"], next_token: meta["next_token"]}}
  end

  def after_focus(%{"meta" => %{"result_count" => 0}}),
    do: {:ok, %{tweets: [], count: 0, next_token: nil}}

  def after_focus(%{"errors" => [%{"detail" => d} | _]}), do: {:error, d}
  def after_focus(other), do: {:error, "Unexpected: #{inspect(other)}"}
end
