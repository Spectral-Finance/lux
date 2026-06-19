defmodule Lux.Lenses.Discord.Roles.ListRoles do
  @moduledoc """
  A lens for listing roles of a Discord guild.

  Requires guild_id.
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "List Discord Guild Roles",
    description: "Lists all roles in a specific Discord guild",
    url: "https://discord.com/api/v10/guilds/:guild_id/roles",
    method: :get,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild to list roles for",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["guild_id"]
    }

  @doc """
  Transforms the list of roles response into a cleaner format.
  """
  @impl true
  def after_focus(roles) when is_list(roles) do
    parsed_roles =
      Enum.map(roles, fn role ->
        %{
          id: role["id"],
          name: role["name"],
          color: role["color"],
          hoist: role["hoist"],
          position: role["position"],
          permissions: role["permissions"],
          managed: role["managed"],
          mentionable: role["mentionable"]
        }
      end)

    {:ok, parsed_roles}
  end

  def after_focus(%{"message" => message}) do
    {:error, %{"message" => message}}
  end

  def after_focus(other), do: {:error, other}
end
