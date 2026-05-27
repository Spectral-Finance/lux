defmodule Lux.Lenses.Twitter.Tweets do
  @moduledoc """
  Fetches tweets for a user (timeline).

  ## Examples

      # Get user's timeline
      Lux.Lenses.Twitter.Tweets.focus(%{
        user_id: "1234567890",
        max_results: 10
      })
  """

  use Lux.Lens,
    name: "Twitter / User Timeline",
    description: "Fetches recent Tweets from a user's timeline",
    url: "/2/users/:user_id/tweets",
    method: :get,
    headers: [{"Content-Type", "application/json"}],
    auth: %{type: :custom, auth_function: &Lux.Integrations.Twitter.add_bearer_token/1},
    schema: %{
      type: :object,
      properties: %{
        user_id: %{type: :string, description: "The user ID whose tweets to fetch"},
        max_results: %{type: :integer, description: "Max results per page (5-100)", default: 10},
        exclude: %{type: :string, description: "Exclude retweets/replies (retweets, replies)"},
        pagination_token: %{type: :string, description: "Token for the next page"},
        start_time: %{type: :string, description: "Oldest timestamp (ISO 8601)"},
        end_time: %{type: :string, description: "Newest timestamp (ISO 8601)"}
      },
      required: ["user_id"]
    },
    transform: &__MODULE__.transform_response/1

  @doc false
  def transform_response(response) do
    case response do
      %{status: 200, body: %{"data" => tweets}} ->
        meta = Map.get(response.body, "meta", %{})
        {:ok, %{tweets: tweets, meta: meta, result_count: length(tweets)}}

      %{status: status, body: %{"errors" => errors}} ->
        {:error, %{status: status, errors: errors}}

      %{status: status, body: body} ->
        {:error, %{status: status, body: body}}
    end
  end
end
