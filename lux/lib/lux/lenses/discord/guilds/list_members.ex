defmodule Lux.Lenses.Discord.Guilds.ListMembers do
  @moduledoc """
  A lens for listing members of a Discord guild.

  Provides pagination support (limit, after) and returns:
  - User ID, username, discriminator, avatar
  - Member roles, nickname, joined_at

  ## Examples
      iex> ListMembers.focus(%{
      ...>   guild_id: "123456789",
      ...>   limit: 50
      ...> })
      {:ok, [
        %{
          user: %{id: "111", username: "Alice", discriminator: "0001"},
          roles: ["role_id_1", "role_id_2"],
          nick: "Ali",
          joined_at: "2024-01-01T00:00:00Z"
        }
      ]}
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "List Discord Members",
    description: "Lists members of a Discord guild with pagination",
    url: "https://discord.com/api/v10/guilds/:guild_id/members",
    method: :get,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild to list members from",
          pattern: "^[0-9]{17,20}$"
        },
        limit: %{
          type: :integer,
          description: "Max number of members to return (1-1000)",
          minimum: 1,
          maximum: 1000,
          default: 50
        },
        after: %{
          type: :string,
          description: "Get members after this user ID"
        }
      },
      required: ["guild_id"]
    }

  @impl true
  def after_focus(members) when is_list(members) do
    {:ok,
     Enum.map(members, fn member ->
       %{
         user: %{
           id: member["user"]["id"],
           username: member["user"]["username"],
           discriminator: member["user"]["discriminator"],
           avatar: member["user"]["avatar"],
           bot: member["user"]["bot"]
         },
         roles: member["roles"] || [],
         nick: member["nick"],
         joined_at: member["joined_at"],
         premium_since: member["premium_since"],
         deaf: member["deaf"],
         mute: member["mute"]
       }
     end)}
  end

  def after_focus(%{"message" => message}) do
    {:error, %{"message" => message}}
  end
end
