defmodule Lux.Prisms.Discord.Moderation.ListBans do
  @moduledoc "A prism for listing all bans in a Discord guild."
  use Lux.Prism,
    name: "List Discord Bans",
    description: "Lists all banned users in a Discord guild",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, pattern: "^[0-9]{17,20}$"},
        limit: %{type: :integer, minimum: 1, maximum: 1000}
      },
      required: ["guild_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        bans: %{type: :array},
        guild_id: %{type: :string},
        count: %{type: :integer}
      }
    }
  def handler(input, _ctx) do
    query = if input["limit"], do: "?limit=#{input["limit"]}", else: ""
    case Lux.Integrations.Discord.Client.request(:get, "/guilds/#{input["guild_id"]}/bans#{query}") do
      {:ok, bans} when is_list(bans) -> {:ok, %{bans: bans, guild_id: input["guild_id"], count: length(bans)}}
      {:ok, bans} -> {:ok, %{bans: bans || [], guild_id: input["guild_id"], count: 0}}
      {:error, reason} -> {:error, "List bans failed: #{reason}"}
    end
  end
end
