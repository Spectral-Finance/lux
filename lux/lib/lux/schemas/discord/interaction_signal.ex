defmodule Lux.Schemas.Discord.InteractionSignal do
  @moduledoc """
  Signal schema for Discord interaction events.

  Covers slash commands, button clicks, select menu choices,
  and modal submissions. Used by Discord agents to handle
  interactive UI components.
  """

  use Lux.SignalSchema,
    name: "discord.interaction",
    version: "1.0.0",
    description: "Represents a Discord interaction (slash command, button, select menu, modal)",
    tags: ["discord", "interaction", "commands"],
    schema: %{
      type: :object,
      required: ["interaction_id", "type", "channel_id"],
      properties: %{
        interaction_id: %{
          type: :string,
          description: "Unique interaction snowflake ID",
          pattern: "^[0-9]{17,20}$"
        },
        application_id: %{
          type: :string,
          description: "Discord application ID"
        },
        type: %{
          type: :integer,
          description: "Interaction type: 1=Ping, 2=ApplicationCommand, 3=MessageComponent, 4=ApplicationCommandAutocomplete, 5=ModalSubmit",
          enum: [1, 2, 3, 4, 5]
        },
        channel_id: %{
          type: :string,
          pattern: "^[0-9]{17,20}$"
        },
        guild_id: %{
          type: :string,
          description: "Guild ID (nil for DM interactions)"
        },
        token: %{
          type: :string,
          description: "Continuation token for responding to the interaction"
        },
        user: %{
          type: :object,
          description: "The user who triggered the interaction",
          properties: %{
            id: %{type: :string},
            username: %{type: :string},
            bot: %{type: :boolean, default: false}
          },
          required: ["id", "username"]
        },
        data: %{
          type: :object,
          description: "Interaction-specific data (command name, custom_id, values, etc.)",
          properties: %{
            id: %{type: :string, description: "Command/component ID"},
            name: %{type: :string, description: "Slash command name"},
            custom_id: %{type: :string, description: "Component custom_id"},
            component_type: %{type: :integer, description: "2=Button, 3=SelectMenu, 4=TextInput"},
            values: %{type: :array, description: "Selected values for select menus", items: %{type: :string}},
            options: %{type: :array, description: "Slash command options", items: %{type: :object}}
          }
        }
      }
    }
end
