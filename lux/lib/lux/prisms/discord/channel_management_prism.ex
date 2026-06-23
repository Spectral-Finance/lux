defmodule Lux.Prisms.Discord.ChannelManagementPrism do
  use Lux.Prism,
    name: "Discord Channel Management",
    description: "Manage Discord channels (create, update permissions, archive)",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, enum: ["create", "update_permissions", "archive"]},
        guild_id: %{type: :string},
        channel_id: %{type: :string},
        name: %{type: :string},
        type: %{type: :integer},
        overwrite_id: %{type: :string},
        allow: %{type: :string},
        deny: %{type: :string}
      },
      required: ["action"]
    }

  alias Lux.Utils.DiscordApi

  def handler(%{"action" => "create", "guild_id" => guild_id, "name" => name} = input, _ctx) do
    payload = %{name: name}
    payload = if type = Map.get(input, "type"), do: Map.put(payload, :type, type), else: payload
    DiscordApi.request(:post, "/guilds/#{guild_id}/channels", payload)
  end

  def handler(%{"action" => "create"}, _ctx), do: {:error, "guild_id and name are required for create"}

  def handler(%{"action" => "update_permissions", "channel_id" => channel_id, "overwrite_id" => overwrite_id} = input, _ctx) do
    payload = %{
      allow: Map.get(input, "allow", "0"),
      deny: Map.get(input, "deny", "0"),
      type: Map.get(input, "type", 1) # 1 for member, 0 for role
    }
    DiscordApi.request(:put, "/channels/#{channel_id}/permissions/#{overwrite_id}", payload)
  end

  def handler(%{"action" => "update_permissions"}, _ctx), do: {:error, "overwrite_id is required for update_permissions"}

  def handler(%{"action" => "archive", "channel_id" => channel_id}, _ctx) do
    # Archiving is done by setting archived to true for thread channels
    DiscordApi.request(:patch, "/channels/#{channel_id}", %{archived: true})
  end

  def handler(%{"action" => "archive"}, _ctx), do: {:error, "channel_id is required for archive"}

  def handler(_, _), do: {:error, "Invalid action or missing required parameters"}
end
