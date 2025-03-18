defmodule Lux.Prisms.Discord.CommandLens do
  @moduledoc """
  A lens for reading Discord Application Command interactions.
  This lens provides functionality to:
  1. Parse and validate incoming Discord Application Command interactions
  2. Handle different types of command interactions (CHAT_INPUT, USER, MESSAGE)
  3. Process command options and parameters
  ## Examples
      # Parse a chat input command
      iex> Lux.Prisms.Discord.CommandLens.focus(%{
      ...>   type: 2,
      ...>   data: %{
      ...>     name: "ping",
      ...>     type: 1
      ...>   }
      ...> })
      {:ok, %{command: %{name: "ping", type: "CHAT_INPUT"}}}
  ## Error Cases
      # Invalid interaction type
      iex> Lux.Prisms.Discord.CommandLens.focus(%{type: 1})
      {:error, %{type: "validation_error", message: "Invalid interaction type"}}
  """

  use Lux.Lens,
    name: "Discord Command Lens",
    description: "Reads Discord Application Command interactions",
    schema: %{
      type: :object,
      properties: %{
        id: %{
          type: :string,
          description: "Interaction ID",
          pattern: "^[0-9]{17,20}$"
        },
        application_id: %{
          type: :string,
          description: "Application ID",
          pattern: "^[0-9]{17,20}$"
        },
        type: %{
          type: :integer,
          description: "Interaction type (2 for APPLICATION_COMMAND)",
          enum: [2]
        },
        data: %{
          type: :object,
          properties: %{
            id: %{
              type: :string,
              description: "Command ID",
              pattern: "^[0-9]{17,20}$"
            },
            name: %{
              type: :string,
              description: "Command name",
              minLength: 1,
              maxLength: 32
            },
            type: %{
              type: :integer,
              description: "Command type",
              enum: [1, 2, 3],
              mapping: %{
                1 => "CHAT_INPUT",
                2 => "USER",
                3 => "MESSAGE"
              }
            },
            options: %{
              type: :array,
              items: %{
                type: :object,
                properties: %{
                  name: %{type: :string},
                  type: %{type: :integer},
                  value: %{type: [:string, :integer, :boolean]}
                },
                required: ["name", "type"]
              }
            }
          },
          required: ["id", "name", "type"]
        },
        guild_id: %{
          type: :string,
          description: "Guild ID where the command was executed"
        },
        channel_id: %{
          type: :string,
          description: "Channel ID where the command was executed"
        },
        member: %{
          type: :object,
          description: "Guild member data",
          properties: %{
            user: %{
              type: :object,
              properties: %{
                id: %{type: :string},
                username: %{type: :string},
                discriminator: %{type: :string},
                avatar: %{type: [:string, :null]}
              }
            },
            roles: %{
              type: :array,
              items: %{type: :string}
            },
            permissions: %{type: :string},
            nick: %{type: [:string, :null]}
          }
        },
        user: %{
          type: :object,
          description: "User data (for DM interactions)",
          properties: %{
            id: %{type: :string},
            username: %{type: :string},
            discriminator: %{type: :string},
            avatar: %{type: [:string, :null]}
          }
        }
      },
      required: ["id", "application_id", "type", "data"]
    }

  require Logger

  @impl true
  def after_focus(%{data: %{type: type}} = input) when type in [1, 2, 3] do
    command_type = case type do
      1 -> "CHAT_INPUT"
      2 -> "USER"
      3 -> "MESSAGE"
    end

    processed = %{
      command: %{
        id: input.data.id,
        name: input.data.name,
        type: command_type,
        options: input.data[:options],
        guild_id: input[:guild_id],
        channel_id: input[:channel_id],
        member: input[:member],
        user: input[:user]
      }
    }

    {:ok, processed}
  end

  def after_focus(%{data: %{type: type}}) do
    {:error, "Unsupported command type: #{type}"}
  end

  def after_focus(%{data: data}) do
    {:error, "Invalid command data structure: #{inspect(data)}"}
  end

  def after_focus(input) do
    Logger.error("Invalid input format: #{inspect(input)}")
    {:error, "Invalid input format"}
  end
end
