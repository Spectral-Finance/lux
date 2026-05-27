defmodule Lux.Lenses.Twitter.Users.Lookup do
  @moduledoc """
  Looks up Twitter users by username or ID.

  ## Examples

      # By username
      Lux.Lenses.Twitter.Users.Lookup.focus(%{username: "elonmusk"})

      # By ID
      Lux.Lenses.Twitter.Users.Lookup.focus(%{user_id: "1234567890"})
  """

  use Lux.Lens,
    name: "Twitter / User Lookup",
    description: "Looks up a Twitter user by username or user ID",
    url: "/2/users/by/username/:username",
    method: :get,
    headers: [{"Content-Type", "application/json"}],
    auth: %{type: :custom, auth_function: &Lux.Integrations.Twitter.add_bearer_token/1},
    schema: %{
      type: :object,
      properties: %{
        username: %{type: :string, description: "Twitter username (without @)"},
        user_id: %{type: :string, description: "Twitter user ID (alternative to username)"}
      }
    },
    transform: &__MODULE__.transform_response/1

  @doc false
  def transform_response(response) do
    case response do
      %{status: 200, body: %{"data" => user}} ->
        {:ok, user}

      %{status: status, body: body} ->
        {:error, %{status: status, body: body}}
    end
  end
end
