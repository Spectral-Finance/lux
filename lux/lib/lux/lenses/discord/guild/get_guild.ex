defmodule Lux.Lenses.Discord.Guild.GetGuild do
  use Lux.Lens,
    name: "Get Discord Guild",
    description: "Retrieves information about a Discord guild",
    url: "/guilds/:guild_id",
    method: :get,
    headers: Lux.Integrations.Discord.headers(),
    auth: Lux.Integrations.Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "Guild ID", pattern: "^[0-9]{17,20}$"}
      },
      required: ["guild_id"]
    }

  def after_focus(response) do
    {:ok, %{
      id: response["id"],
      name: response["name"],
      description: response["description"],
      member_count: response["member_count"],
      channels: response["channels"],
      roles: response["roles"]
    }}
  end
end
