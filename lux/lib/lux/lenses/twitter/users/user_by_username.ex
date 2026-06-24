defmodule Lux.Lenses.Twitter.Users.UserByUsername do
  @moduledoc """
  A lens for fetching a Twitter/X user by their username.

  ## Examples

      iex> UserByUsername.focus(%{username: "LuxAgent"})
      {:ok, %{data: %{id: "...", name: "Lux Agent", username: "LuxAgent"}}}
  """

  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "User by Username",
    description: "Fetches a Twitter/X user by their @username",
    url: "#{Twitter.base_url()}/users/by/username/:username",
    method: :get,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    schema: %{
      type: :object,
      properties: %{
        username: %{
          type: :string,
          description: "The username to look up (without @)"
        },
        expansions: %{
          type: :array,
          description: "Expansion fields to include",
          items: %{type: :string}
        },
        user_fields: %{
          type: :array,
          description: "Additional user fields to return",
          items: %{type: :string}
        }
      },
      required: ["username"]
    }

  def after_focus(%{"data" => data} = body) do
    result = %{data: data}

    result =
      case Map.get(body, "includes") do
        nil -> result
        includes -> Map.put(result, :includes, includes)
      end

    {:ok, result}
  end

  def after_focus(%{"errors" => errors}) do
    {:error, errors}
  end

  def after_focus(body) do
    {:error, %{error: "Unexpected response", raw: body}}
  end
end
