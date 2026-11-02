defmodule Lux.Schemas.DiscordInteractionSchema do
  @moduledoc """
  Schema for Discord interaction signals.
  Covers slash commands, buttons, select menus, modals, and context menus.
  """

  use Lux.SignalSchema,
    name: "discord.interaction",
    version: "1.0.0",
    description: "Represents Discord interaction events (commands, buttons, select menus, modals)",
    schema: %{
      type: :object,
      properties: %{
        id: %{type: :string, description: "Interaction ID"},
        application_id: %{type: :string, description: "Application/Bot ID"},
        type: %{
          type: :integer,
          description: "Interaction type (1: Ping, 2: ApplicationCommand, 3: MessageComponent, 4: Autocomplete, 5: ModalSubmit)"
        },
        type_name: %{
          type: :string,
          enum: ["ping", "application_command", "message_component", "application_command_autocomplete", "modal_submit"],
          description: "Human-readable interaction type name"
        },
        data: %{
          type: :object,
          properties: %{
            id: %{type: :string},
            name: %{type: :string},
            type: %{type: :integer},
            custom_id: %{type: :string},
            component_type: %{type: :integer},
            values: %{
              type: :array,
              items: %{type: :string}
            },
            options: %{
              type: :array,
              items: %{type: :object}
            }
          }
        },
        guild_id: %{type: :string, description: "Guild ID where interaction occurred"},
        channel_id: %{type: :string, description: "Channel ID where interaction occurred"},
        user: %{
          type: :object,
          properties: %{
            id: %{type: :string},
            username: %{type: :string},
            discriminator: %{type: :string},
            avatar: %{type: :string}
          },
          required: ["id", "username"]
        },
        token: %{type: :string, description: "Interaction continuation token"},
        version: %{type: :integer, description: "Interaction protocol version"}
      },
      required: ["id", "type", "token"]
    },
    tags: ["discord", "interactions", "signals"],
    compatibility: :full,
    format: :json
end
