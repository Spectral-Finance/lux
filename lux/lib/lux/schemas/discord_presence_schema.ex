defmodule Lux.Schemas.DiscordPresenceSchema do
  @moduledoc """
  Schema for Discord presence update signals.
  Tracks user status, active games/activities, and platform connections across guilds.
  """

  use Lux.SignalSchema,
    name: "discord.presence",
    version: "1.0.0",
    description: "Represents Discord presence update events (status, activities, client platforms)",
    schema: %{
      type: :object,
      properties: %{
        user_id: %{type: :string, description: "Discord user ID"},
        guild_id: %{type: :string, description: "Guild ID for guild-specific presence"},
        status: %{
          type: :string,
          enum: ["online", "idle", "dnd", "offline"],
          description: "Current presence status"
        },
        activities: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              name: %{type: :string},
              type: %{type: :integer, description: "0: Game, 1: Streaming, 2: Listening, 3: Watching, 4: Custom, 5: Competing"},
              state: %{type: :string},
              details: %{type: :string},
              url: %{type: :string}
            },
            required: ["name"]
          }
        },
        client_status: %{
          type: :object,
          properties: %{
            desktop: %{type: :string},
            mobile: %{type: :string},
            web: %{type: :string}
          }
        }
      },
      required: ["user_id", "status"]
    },
    tags: ["discord", "presence", "signals"],
    compatibility: :full,
    format: :json
end
