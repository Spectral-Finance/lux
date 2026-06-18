defmodule Lux.Lenses.Discord.Guilds.GetGuild do
  @moduledoc """
  A lens for getting detailed information about a specific Discord guild.

  Provides guild details including:
  - Name, description, owner
  - Member count, channel count, role count
  - Verification level, explicit content filter

  ## Examples
      iex> GetGuild.focus(%{
      ...>   guild_id: "123456789"
      ...> })
      {:ok, %{
        id: "123456789",
        name: "My Server",
        description: "A cool community",
        owner_id: "987654321",
        member_count: 150,
        verification_level: 0
      }}
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "Get Discord Guild",
    description: "Gets detailed information about a Discord guild",
    url: "https://discord.com/api/v10/guilds/:guild_id",
    method: :get,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild to get information about",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["guild_id"]
    }

  @impl true
  def after_focus(%{"id" => id, "name" => name} = guild) do
    {:ok,
     %{
       id: id,
       name: name,
       description: guild["description"],
       owner_id: guild["owner_id"],
       member_count: guild["member_count"],
       max_members: guild["max_members"],
       verification_level: guild["verification_level"],
       explicit_content_filter: guild["explicit_content_filter"],
       default_message_notifications: guild["default_message_notifications"],
       mfa_level: guild["mfa_level"],
       premium_tier: guild["premium_tier"],
       premium_subscription_count: guild["premium_subscription_count"],
       system_channel_id: guild["system_channel_id"],
       afk_channel_id: guild["afk_channel_id"],
       icon: guild["icon"],
       splash: guild["splash"],
       banner: guild["banner"]
     }}
  end

  def after_focus(%{"message" => message}) do
    {:error, %{"message" => message}}
  end
end
