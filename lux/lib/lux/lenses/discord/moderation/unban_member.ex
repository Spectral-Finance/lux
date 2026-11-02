defmodule Lux.Lenses.Discord.Moderation.UnbanMember do
  @moduledoc """
  A lens for removing a ban for a user in a Discord guild.
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "Unban Discord Member",
    description: "Removes the ban for a user in a guild",
    url: "https://discord.com/api/v10/guilds/:guild_id/bans/:user_id",
    method: :delete,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "Guild Snowflake ID",
          pattern: "^[0-9]{17,20}$"
        },
        user_id: %{
          type: :string,
          description: "Target user Snowflake ID",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["guild_id", "user_id"]
    }

  @impl true
  def after_focus("") do
    {:ok, %{unbanned: true}}
  end

  def after_focus(nil) do
    {:ok, %{unbanned: true}}
  end

  def after_focus(other), do: {:ok, other}
end
