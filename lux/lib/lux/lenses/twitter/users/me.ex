defmodule Lux.Lenses.Twitter.Users.Me do
  @moduledoc """
  Fetches the authenticated user's profile.

  ## Examples

      Lux.Lenses.Twitter.Users.Me.focus(%{})
  """

  use Lux.Lens,
    name: "Twitter / My Profile",
    description: "Returns the authenticated user's public profile information",
    url: "/2/users/me",
    method: :get,
    headers: [{"Content-Type", "application/json"}],
    auth: %{type: :custom, auth_function: &Lux.Integrations.Twitter.add_bearer_token/1},
    schema: %{
      type: :object,
      properties: %{
        expansions: %{type: :string, description: "Additional data to include"}
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
