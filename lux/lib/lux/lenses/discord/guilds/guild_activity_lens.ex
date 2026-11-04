defmodule Lux.Lenses.Discord.Guilds.GuildActivityLens do
  @moduledoc """
  A lens for inspecting Discord guild metadata, roles, and member activity profiles (`Spectral-Finance/lux#55`).
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "Discord Guild Activity & Profile Lens",
    description: "Fetches guild details, role hierarchy, and activity summary for a Discord server",
    url: "https://discord.com/api/v10/guilds/:guild_id",
    method: :get,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the Discord guild to inspect",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["guild_id"]
    }

  @impl true
  def after_focus(%{"id" => id, "name" => name} = body) do
    roles =
      body
      |> Map.get("roles", [])
      |> Enum.map(fn r ->
        %{
          id: r["id"],
          name: r["name"],
          permissions: r["permissions"],
          position: r["position"] || 0
        }
      end)
      |> Enum.sort_by(& &1.position, :desc)

    {:ok,
     %{
       guild_id: id,
       name: name,
       owner_id: body["owner_id"],
       roles: roles,
       approximate_member_count: body["approximate_member_count"] || 0
     }}
  end

  def after_focus(%{"message" => message}) do
    {:error, %{"message" => message}}
  end
end
