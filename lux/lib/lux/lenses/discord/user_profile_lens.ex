defmodule Lux.Lenses.Discord.UserProfileLens do
  @moduledoc """
  A lens for retrieving and profiling a Discord guild member's identity, roles,
  and permissions.

  ## Examples

      iex> Lux.Lenses.Discord.UserProfileLens.focus(%{
      ...>   guild_id: "123456789",
      ...>   user_id: "987654321"
      ...> })
      {:ok, %{
        user: %{id: "987654321", username: "Contributor"},
        roles: ["123", "456"],
        joined_at: "2026-01-01T00:00:00Z"
      }}
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "Read Discord Member Profile",
    description: "Reads member profile and permissions from a Discord guild",
    url: "https://discord.com/api/v10/guilds/:guild_id/members/:user_id",
    method: :get,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "Discord Guild ID"},
        user_id: %{type: :string, description: "Discord User ID"}
      },
      required: ["guild_id", "user_id"]
    }

  @doc """
  Transforms the raw response into a normalized user profile summary.
  """
  def transform_response({:ok, %{status: 200, body: body}}) do
    {:ok,
     %{
       user_id: get_in(body, ["user", "id"]),
       username: get_in(body, ["user", "username"]),
       roles: Map.get(body, "roles", []),
       joined_at: Map.get(body, "joined_at"),
       raw: body
     }}
  end

  def transform_response({:ok, %{status: status, body: body}}) do
    {:error, "Failed to read Discord user profile: HTTP #{status} - #{inspect(body)}"}
  end

  def transform_response({:error, reason}) do
    {:error, reason}
  end
end
