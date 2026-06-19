defmodule Lux.Lenses.Discord.Members.ReadMember do
  @moduledoc """
  A lens for reading information about a specific member in a Discord guild.

  Requires guild_id and user_id.
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "Read Discord Guild Member",
    description: "Reads information about a specific Discord guild member",
    url: "https://discord.com/api/v10/guilds/:guild_id/members/:user_id",
    method: :get,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild",
          pattern: "^[0-9]{17,20}$"
        },
        user_id: %{
          type: :string,
          description: "The ID of the user",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["guild_id", "user_id"]
    }

  @doc """
  Transforms the guild member details response into a cleaner format.
  """
  @impl true
  def after_focus(%{"user" => %{"id" => id, "username" => username}} = member) do
    {:ok,
     %{
       user: %{
         id: id,
         username: username,
         discriminator: member["user"]["discriminator"],
         avatar: member["user"]["avatar"]
       },
       nick: member["nick"],
       roles: member["roles"],
       joined_at: member["joined_at"],
       premium_since: member["premium_since"],
       deaf: member["deaf"],
       mute: member["mute"],
       pending: member["pending"]
     }}
  end

  def after_focus(%{"message" => message}) do
    {:error, %{"message" => message}}
  end

  def after_focus(other), do: {:error, other}
end
