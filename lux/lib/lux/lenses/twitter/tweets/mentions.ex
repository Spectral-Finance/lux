defmodule Lux.Lenses.Twitter.Tweets.Mentions do
  @moduledoc """
  Fetches Tweets that mention a user.

  ## Examples

      Lux.Lenses.Twitter.Tweets.Mentions.focus(%{user_id: "1234567890", max_results: 10})
  """

  use Lux.Lens,
    name: "Twitter / User Mentions",
    description: "Fetches Tweets that mention a specified user",
    url: "/2/users/:user_id/mentions",
    method: :get,
    headers: [{"Content-Type", "application/json"}],
    auth: %{type: :custom, auth_function: &Lux.Integrations.Twitter.add_bearer_token/1},
    schema: %{
      type: :object,
      properties: %{
        user_id: %{type: :string, description: "User ID to get mentions for"},
        max_results: %{type: :integer, description: "Results per page (5-100)", default: 10},
        pagination_token: %{type: :string, description: "Token for next page"}
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

      %{status: status, body: body} ->
        {:error, %{status: status, body: body}}
    end
  end
end
