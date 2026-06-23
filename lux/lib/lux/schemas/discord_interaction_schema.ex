defmodule Lux.Schemas.DiscordInteractionSchema do
  @moduledoc false
  use Lux.SignalSchema,
    name: "discord_interaction",
    version: "1.0.0",
    description: "Represents an interaction (slash command, button, menu) in Discord",
    schema: %{
      type: :object,
      properties: %{
        type: %{
          type: :string,
          enum: ["command", "button", "select_menu", "modal", "context_menu"],
          description: "Interaction type"
        },
        id: %{type: :string, description: "Interaction ID"},
        name: %{type: :string, description: "Command or component name"},
        custom_id: %{type: :string, description: "Custom ID for buttons/menus"},
        values: %{
          type: :array,
          items: %{type: :string},
          description: "Selected values for menus"
        },
        user_id: %{type: :string, description: "User ID who triggered interaction"},
        channel_id: %{type: :string, description: "Channel ID"},
        guild_id: %{type: :string, description: "Guild ID"}
      },
      required: ["type", "id", "user_id"]
    }
end
