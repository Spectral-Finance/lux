defmodule Lux.Schemas.Discord.VoiceSignalSchema do
  @moduledoc """
  Schema definition for Discord voice state and audio transmission signals.
  """

  use Lux.SignalSchema,
    name: "discord_voice_signal",
    version: "1.0.0",
    description: "Represents voice channel connections, mutes, deafs, and speaking events",
    schema: %{
      type: :object,
      properties: %{
        user_id: %{type: :string, description: "Speaking or connected user snowflake"},
        guild_id: %{type: :string, description: "Associated guild snowflake"},
        channel_id: %{type: [:string, :null], description: "Voice channel snowflake"},
        action: %{
          type: :string,
          enum: ["join", "leave", "mute", "deaf", "speaking"]
        },
        speaking: %{type: :boolean, description: "Whether the user is currently speaking"}
      },
      required: ["user_id", "guild_id", "action"]
    }
end
