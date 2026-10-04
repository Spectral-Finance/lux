defmodule Lux.Schemas.Telegram.TelegramCommandSchema do
  @moduledoc """
  Schema definition for Telegram bot command signals.
  """

  use Lux.SignalSchema,
    name: "Telegram Command Schema",
    description: "Schema for parsed Telegram bot commands with arguments and flags",
    schema: %{
      type: :object,
      properties: %{
        command: %{type: :string, description: "Command name without slash"},
        subcommand: %{type: :string, description: "Subcommand name if provided"},
        args: %{type: :array, items: %{type: :string}, description: "Positional arguments"},
        named_args: %{type: :object, description: "Key-value options and flags"},
        flags: %{type: :array, items: %{type: :string}, description: "Boolean flag switches"},
        user_id: %{type: :integer, description: "User executing the command"},
        chat_id: %{type: :integer, description: "Chat where command was issued"}
      },
      required: ["command", "chat_id", "user_id"]
    }
end
