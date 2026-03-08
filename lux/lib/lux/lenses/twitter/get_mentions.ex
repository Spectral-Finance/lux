defmodule Lux.Lenses.Twitter.GetMentions do
  @moduledoc """
  Lens for fetching tweets mentioning a user via Twitter API v2.
  """

  use Lux.Lens,
    name: "Get Mentions",
    description: "Fetches tweets mentioning a user",
    url: "https://api.twitter.com/2/users/:id/mentions",
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
        max_results: %{type: :integer, default: 10}
      },
      required: ["user_id"]
    }

  @default_tweet_fields "id,text,author_id,created_at,public_metrics"

  @impl true
  def before_focus(params) do
    user_id = params[:user_id] || params["user_id"]

    query_params = %{
      "max_results" => params[:max_results] || 10,
      "tweet.fields" => @default_tweet_fields
    }

    %{url: "https://api.twitter.com/2/users/#{user_id}/mentions", params: query_params}
  end

  @impl true
  def after_focus(%{"data" => tweets, "meta" => meta}) do
    formatted =
      Enum.map(tweets, fn t ->
        %{
          id: t["id"],
          text: t["text"],
          author_id: t["author_id"],
          created_at: t["created_at"]
        }
      end)

    {:ok, %{mentions: formatted, count: meta["result_count"], next_token: meta["next_token"]}}
  end

  def after_focus(%{"meta" => %{"result_count" => 0}}),
    do: {:ok, %{mentions: [], count: 0, next_token: nil}}

  def after_focus(%{"errors" => [%{"detail" => d} | _]}), do: {:error, d}
  def after_focus(other), do: {:error, "Unexpected: #{inspect(other)}"}
end
