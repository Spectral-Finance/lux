defmodule Lux.Schemas.Discord.MessageSignal do
  @moduledoc """
  Signal schema for Discord message events.

  Captures the full Discord message payload including content,
  attachments, embeds, components, and full channel/guild/author metadata.
  Used by Discord agents to route and process incoming message events.
  """

  use Lux.SignalSchema,
    name: "discord.message",
    version: "1.0.0",
    description: "Represents a Discord message event with full metadata",
    tags: ["discord", "messaging", "social"],
    schema: %{
      type: :object,
      required: ["message_id", "channel_id", "content"],
      properties: %{
        message_id: %{
          type: :string,
          description: "Unique Discord snowflake ID of the message",
          pattern: "^[0-9]{17,20}$"
        },
        channel_id: %{
          type: :string,
          description: "ID of the channel the message was sent in",
          pattern: "^[0-9]{17,20}$"
        },
        guild_id: %{
          type: :string,
          description: "ID of the guild/server (nil for DMs)",
          pattern: "^[0-9]{17,20}$"
        },
        content: %{
          type: :string,
          description: "Plain text content of the message (up to 2000 chars)",
          maxLength: 2000
        },
        author: %{
          type: :object,
          description: "The user who sent the message",
          properties: %{
            id: %{type: :string},
            username: %{type: :string},
            discriminator: %{type: :string},
            bot: %{type: :boolean, default: false}
          },
          required: ["id", "username"]
        },
        attachments: %{
          type: :array,
          description: "File attachments",
          items: %{
            type: :object,
            properties: %{
              id: %{type: :string},
              filename: %{type: :string},
              url: %{type: :string},
              content_type: %{type: :string},
              size: %{type: :integer}
            }
          },
          default: []
        },
        embeds: %{
          type: :array,
          description: "Rich embed objects attached to the message",
          items: %{type: :object},
          default: []
        },
        mentions: %{
          type: :array,
          description: "Users mentioned in the message",
          items: %{type: :object},
          default: []
        },
        referenced_message_id: %{
          type: :string,
          description: "ID of the message being replied to, if any"
        },
        timestamp: %{
          type: :string,
          description: "ISO8601 timestamp of when the message was sent"
        },
        edited_timestamp: %{
          type: :string,
          description: "ISO8601 timestamp of last edit, if edited"
        }
      }
    }
end
