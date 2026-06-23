defmodule Lux.Prisms.Discord.MessageManagementPrism do
  use Lux.Prism,
    name: "Discord Message Management",
    description: "Manage Discord messages (create, edit, delete, bulk delete)",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, enum: ["create", "edit", "delete", "bulk_delete"]},
        channel_id: %{type: :string},
        message_id: %{type: :string},
        content: %{type: :string},
        messages: %{type: :array, items: %{type: :string}}
      },
      required: ["action", "channel_id"]
    }

  alias Lux.Utils.DiscordApi

  def handler(%{"action" => "create", "channel_id" => channel_id} = input, _ctx) do
    content = Map.get(input, "content", "")
    DiscordApi.request(:post, "/channels/#{channel_id}/messages", %{content: content})
  end

  def handler(%{"action" => "edit", "channel_id" => channel_id, "message_id" => message_id} = input, _ctx) do
    content = Map.get(input, "content", "")
    DiscordApi.request(:patch, "/channels/#{channel_id}/messages/#{message_id}", %{content: content})
  end

  def handler(%{"action" => "edit"}, _ctx), do: {:error, "message_id is required for edit"}

  def handler(%{"action" => "delete", "channel_id" => channel_id, "message_id" => message_id}, _ctx) do
    DiscordApi.request(:delete, "/channels/#{channel_id}/messages/#{message_id}")
  end

  def handler(%{"action" => "delete"}, _ctx), do: {:error, "message_id is required for delete"}

  def handler(%{"action" => "bulk_delete", "channel_id" => channel_id, "messages" => messages}, _ctx) when is_list(messages) do
    DiscordApi.request(:post, "/channels/#{channel_id}/messages/bulk-delete", %{messages: messages})
  end

  def handler(%{"action" => "bulk_delete"}, _ctx), do: {:error, "messages array is required for bulk_delete"}

  def handler(_, _), do: {:error, "Invalid action or missing required parameters"}
end
