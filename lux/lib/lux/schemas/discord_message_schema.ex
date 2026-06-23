defmodule Lux.Schemas.DiscordMessageSchema do
  @moduledoc false
  use Lux.SignalSchema,
    name: "discord_message",
    version: "1.0.0",
    description: "Represents a message sent in a Discord channel",
    schema: %{
      type: :object,
      properties: %{
        content: %{type: :string, description: "Message content"},
        attachments: %{
          type: :array,
          items: %{type: :string},
          description: "List of attachment URLs"
        },
        embeds: %{
          type: :array,
          items: %{type: :object},
          description: "List of embed objects"
        },
        components: %{
          type: :array,
          items: %{type: :object},
          description: "Message interactive components"
        },
        channel_id: %{type: :string, description: "Channel ID"},
        guild_id: %{type: :string, description: "Guild/Server ID"},
        author_id: %{type: :string, description: "Author User ID"}
      },
      required: ["content", "channel_id", "author_id"]
    }
end
