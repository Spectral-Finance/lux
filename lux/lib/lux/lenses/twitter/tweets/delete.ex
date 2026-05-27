defmodule Lux.Lenses.Twitter.Tweets.Delete do
  @moduledoc """
  Deletes a Tweet.

  ## Examples

      Lux.Lenses.Twitter.Tweets.Delete.focus(%{tweet_id: "1234567890"})
  """

  use Lux.Lens,
    name: "Twitter / Delete Tweet",
    description: "Deletes a Tweet by ID",
    url: "/2/tweets/:tweet_id",
    method: :delete,
    headers: [{"Content-Type", "application/json"}],
    auth: %{type: :custom, auth_function: &Lux.Integrations.Twitter.add_bearer_token/1},
    schema: %{
      type: :object,
      properties: %{
        tweet_id: %{type: :string, description: "The Tweet ID to delete"}
      },
      required: ["tweet_id"]
    },
    transform: &__MODULE__.transform_response/1

  @doc false
  def transform_response(response) do
    case response do
      %{status: 200, body: %{"data" => %{"deleted" => true}}} ->
        {:ok, %{deleted: true}}

      %{status: status, body: body} ->
        {:error, %{status: status, body: body}}
    end
  end
end
