defmodule Lux.Lenses.Discord.Moderation.BanMember do
  @moduledoc """
  A lens for banning a user from a Discord guild.
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "Ban Discord Member",
    description: "Bans a user from a guild and optionally deletes previous messages",
    url: "https://discord.com/api/v10/guilds/:guild_id/bans/:user_id",
    method: :put,
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
        },
        delete_message_seconds: %{
          type: :integer,
          description: "Number of seconds to delete messages for, between 0 and 604800 (7 days)"
        }
      },
      required: ["guild_id", "user_id"]
    }

  @impl true
  def before_focus(params) do
    payload = %{}

    payload =
      if Map.get(params, :delete_message_seconds) do
        Map.put(payload, "delete_message_seconds", params.delete_message_seconds)
      else
        payload
      end

    {:ok, payload}
  end

  @impl true
  def after_focus("") do
    {:ok, %{banned: true}}
  end

  def after_focus(nil) do
    {:ok, %{banned: true}}
  end

  def after_focus(other), do: {:ok, other}
end
