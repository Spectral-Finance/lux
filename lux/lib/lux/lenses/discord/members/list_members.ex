defmodule Lux.Lenses.Discord.Members.ListMembers do
  @moduledoc """
  A lens for listing members of a Discord guild.

  Requires guild_id. Supports limit and after query parameters for pagination.
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "List Discord Guild Members",
    description: "Lists members of a specific Discord guild",
    url: "https://discord.com/api/v10/guilds/:guild_id/members",
    method: :get,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild to list members for",
          pattern: "^[0-9]{17,20}$"
        },
        limit: %{
          type: :integer,
          description: "Max number of members to return (1-1000)",
          minimum: 1,
          maximum: 1000
        },
        after: %{
          type: :string,
          description: "The highest user ID in the previous page",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["guild_id"]
    }

  @doc """
  Transforms the list of members response into a cleaner format.
  """
  @impl true
  def after_focus(members) when is_list(members) do
    parsed_members =
      Enum.map(members, fn member ->
        %{
          user: %{
            id: member["user"]["id"],
            username: member["user"]["username"],
            discriminator: member["user"]["discriminator"],
            avatar: member["user"]["avatar"]
          },
          nick: member["nick"],
          roles: member["roles"],
          joined_at: member["joined_at"],
          deaf: member["deaf"],
          mute: member["mute"]
        }
      end)

    {:ok, parsed_members}
  end

  def after_focus(%{"message" => message}) do
    {:error, %{"message" => message}}
  end

  def after_focus(other), do: {:error, other}
end
