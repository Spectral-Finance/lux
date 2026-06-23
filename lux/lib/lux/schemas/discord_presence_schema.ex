defmodule Lux.Schemas.DiscordPresenceSchema do
  @moduledoc false
  use Lux.SignalSchema,
    name: "discord_presence",
    version: "1.0.0",
    description: "Represents user presence and activity status on Discord",
    schema: %{
      type: :object,
      properties: %{
        user_id: %{type: :string, description: "User ID"},
        status: %{
          type: :string,
          enum: ["online", "idle", "dnd", "offline"],
          description: "Status type"
        },
        activities: %{
          type: :array,
          items: %{type: :object},
          description: "Current activities"
        },
        guild_id: %{type: :string, description: "Guild ID if presence is guild-specific"}
      },
      required: ["user_id", "status"]
    }
end
