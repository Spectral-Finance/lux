defmodule Lux.Prisms.Discord.Moderation.BanMember do
  @moduledoc """
  A prism for banning a member from a Discord guild.
  Bans a user from the guild, optionally deleting their messages from the past N days.
  """
  use Lux.Prism,
    name: "Ban Discord Member",
    description: "Bans a member from a Discord guild",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "The ID of the guild", pattern: "^[0-9]{17,20}$"},
        user_id: %{type: :string, description: "The ID of the user to ban", pattern: "^[0-9]{17,20}$"},
        reason: %{type: :string, description: "Reason for the ban", maxLength: 512},
        delete_message_days: %{type: :integer, description: "Delete messages from the past N days (0-7)", minimum: 0, maximum: 7}
      },
      required: ["guild_id", "user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        banned: %{type: :boolean, description: "Whether the user was successfully banned"},
        user_id: %{type: :string, description: "The ID of the banned user"},
        guild_id: %{type: :string, description: "The ID of the guild"}
      }
    }
  def handler(input, _ctx) do
    guild_id = input["guild_id"]
    user_id = input["user_id"]
    body = %{}
    body = if input["reason"], do: Map.put(body, :reason, input["reason"]), else: body
    body = if input["delete_message_days"], do: Map.put(body, :delete_message_days, input["delete_message_days"]), else: body
    case Lux.Integrations.Discord.Client.request(:put, "/guilds/#{guild_id}/bans/#{user_id}", json: body) do
      {:ok, _} -> {:ok, %{banned: true, user_id: user_id, guild_id: guild_id}}
      {:error, reason} -> {:error, "Ban failed: #{reason}"}
    end
  end
end
