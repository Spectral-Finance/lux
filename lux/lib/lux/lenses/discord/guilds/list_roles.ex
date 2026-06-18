defmodule Lux.Lenses.Discord.Guilds.ListRoles do
  @moduledoc """
  A lens for listing roles in a Discord guild.

  Returns role details including:
  - ID, name, color, position
  - Permissions, mentionable, hoist
  - Integration info

  ## Examples
      iex> ListRoles.focus(%{
      ...>   guild_id: "123456789"
      ...> })
      {:ok, [
        %{
          id: "111111111111111111",
          name: "Admin",
          color: 16711680,
          position: 1,
          permissions: "8",
          mentionable: false
        }
      ]}
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "List Discord Roles",
    description: "Lists roles in a Discord guild",
    url: "https://discord.com/api/v10/guilds/:guild_id/roles",
    method: :get,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild to list roles from",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["guild_id"]
    }

  @impl true
  def after_focus(roles) when is_list(roles) do
    {:ok,
     Enum.map(roles, fn role ->
       %{
         id: role["id"],
         name: role["name"],
         color: role["color"],
         hoist: role["hoist"],
         position: role["position"],
         permissions: role["permissions"],
         managed: role["managed"],
         mentionable: role["mentionable"],
         tags: role["tags"]
       }
     end)}
  end

  def after_focus(%{"message" => message}) do
    {:error, %{"message" => message}}
  end
end
