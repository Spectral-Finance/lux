defmodule Lux.Schemas.DiscordMessageSchema do
  @moduledoc """
  Schema for Discord message signals.
  Represents incoming and outgoing messages across Discord guilds and channels.
  """

  use Lux.SignalSchema,
    name: "discord.message",
    version: "1.0.0",
    description: "Represents a Discord message event or outgoing payload",
    schema: %{
      type: :object,
      properties: %{
        id: %{type: :string, description: "Discord message ID (snowflake)"},
        channel_id: %{type: :string, description: "Discord channel ID"},
        guild_id: %{type: :string, description: "Discord guild (server) ID"},
        content: %{type: :string, description: "Message text content"},
        author: %{
          type: :object,
          properties: %{
            id: %{type: :string},
            username: %{type: :string},
            discriminator: %{type: :string},
            avatar: %{type: :string},
            bot: %{type: :boolean}
          },
          required: ["id", "username"]
        },
        attachments: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              id: %{type: :string},
              filename: %{type: :string},
              url: %{type: :string},
              size: %{type: :integer},
              content_type: %{type: :string}
            },
            required: ["id", "filename", "url"]
          }
        },
        embeds: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              title: %{type: :string},
              description: %{type: :string},
              url: %{type: :string},
              color: %{type: :integer},
              fields: %{
                type: :array,
                items: %{
                  type: :object,
                  properties: %{
                    name: %{type: :string},
                    value: %{type: :string},
                    inline: %{type: :boolean}
                  },
                  required: ["name", "value"]
                }
              }
            }
          }
        },
        components: %{
          type: :array,
          items: %{type: :object}
        },
        timestamp: %{type: :string, description: "ISO 8601 timestamp"},
        tts: %{type: :boolean, description: "Text-to-speech flag"}
      },
      required: ["channel_id", "content"]
    },
    tags: ["discord", "messaging", "signals"],
    compatibility: :full,
    format: :json
end
