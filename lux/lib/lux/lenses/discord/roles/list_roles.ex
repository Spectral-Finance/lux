defmodule Lux.Lenses.Discord.Roles.ListRoles do
  @moduledoc """
  A lens for listing Discord roles in a guild.
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
        guild_id: %{type: :string, description: "Guild ID", pattern: "^[0-9]{17,20}$"}
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
         permissions: role["permissions"],
         position: role["position"],
         color: role["color"],
         managed: role["managed"],
         mentionable: role["mentionable"]
       }
     end)}
  end

  def after_focus(%{"message" => message}) do
    {:error, %{"message" => message}}
  end
end
