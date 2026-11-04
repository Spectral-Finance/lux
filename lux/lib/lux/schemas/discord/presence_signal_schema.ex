defmodule Lux.Schemas.Discord.PresenceSignalSchema do
  @moduledoc """
  Schema definition for Discord presence update signals.
  """

  use Lux.SignalSchema,
    name: "discord_presence_signal",
    version: "1.0.0",
    description: "Represents user status changes, activities, and guild presence updates",
    schema: %{
      type: :object,
      properties: %{
        user_id: %{type: :string, description: "Target user snowflake"},
        guild_id: %{type: :string, description: "Associated guild snowflake"},
        status: %{
          type: :string,
          enum: ["online", "dnd", "idle", "offline"]
        },
        activities: %{type: :array, description: "Active games, streams, or custom status"}
      },
      required: ["user_id", "status"]
    }
end
