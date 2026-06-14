defmodule Lux.Prisms.Discord.Moderation.GetMember do
  @moduledoc "A prism for getting detailed information about a guild member."
  use Lux.Prism,
    name: "Get Discord Member Info",
    description: "Gets detailed information about a Discord guild member",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, pattern: "^[0-9]{17,20}$"},
        user_id: %{type: :string, pattern: "^[0-9]{17,20}$"}
      },
      required: ["guild_id", "user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        user_id: %{type: :string},
        roles: %{type: :array},
        joined_at: %{type: :string},
        nickname: %{type: :string}
      }
    }
  def handler(input, _ctx) do
    case Lux.Integrations.Discord.Client.request(:get, "/guilds/#{input["guild_id"]}/members/#{input["user_id"]}") do
      {:ok, m} -> {:ok, %{user_id: m["user"]["id"], username: m["user"]["username"], roles: m["roles"] || [], joined_at: m["joined_at"], nickname: m["nick"]}}
      {:error, reason} -> {:error, "Get member failed: #{reason}"}
    end
  end
end
