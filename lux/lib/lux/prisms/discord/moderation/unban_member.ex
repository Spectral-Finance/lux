defmodule Lux.Prisms.Discord.Moderation.UnbanMember do
  @moduledoc "A prism for unbanning a member from a Discord guild."
  use Lux.Prism,
    name: "Unban Discord Member",
    description: "Removes a ban from a user in a Discord guild",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "The ID of the guild", pattern: "^[0-9]{17,20}$"},
        user_id: %{type: :string, description: "The ID of the user to unban", pattern: "^[0-9]{17,20}$"}
      },
      required: ["guild_id", "user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        unbanned: %{type: :boolean},
        user_id: %{type: :string},
        guild_id: %{type: :string}
      }
    }
  def handler(input, _ctx) do
    guild_id = input["guild_id"]
    user_id = input["user_id"]
    case Lux.Integrations.Discord.Client.request(:delete, "/guilds/#{guild_id}/bans/#{user_id}") do
      {:ok, _} -> {:ok, %{unbanned: true, user_id: user_id, guild_id: guild_id}}
      {:error, reason} -> {:error, "Unban failed: #{reason}"}
    end
  end
end
