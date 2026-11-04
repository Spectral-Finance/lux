defmodule Lux.Schemas.Discord.InteractionSignalSchema do
  @moduledoc """
  Schema definition for Discord interaction signals (slash commands, buttons, menus, modals).
  """

  use Lux.SignalSchema,
    name: "discord_interaction_signal",
    version: "1.0.0",
    description: "Represents an interactive Discord UI or command event",
    schema: %{
      type: :object,
      properties: %{
        interaction_id: %{type: :string, description: "Unique interaction snowflake"},
        type: %{
          type: :string,
          enum: ["slash_command", "button", "select_menu", "modal", "context_menu"]
        },
        name: %{type: :string, description: "Command or component name"},
        user_id: %{type: :string, description: "Executing user snowflake"},
        channel_id: %{type: :string, description: "Source channel snowflake"},
        guild_id: %{type: :string, description: "Source guild snowflake"},
        data: %{type: :object, description: "Interaction options and custom payload"}
      },
      required: ["interaction_id", "type", "user_id"]
    }
end
