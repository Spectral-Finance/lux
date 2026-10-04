defmodule Lux.Prisms.Telegram.CommandRouterPrism do
  @moduledoc """
  Prism for parsing and routing Telegram bot commands with type coercion and flag extraction.
  """

  use Lux.Prism,
    name: "Telegram Command Router Prism",
    description: "Parses Telegram command strings, subcommands, named flags, and validates permissions.",
    input_schema: %{
      type: :object,
      properties: %{
        command_text: %{type: :string, description: "Raw command text starting with /"},
        bot_username: %{type: :string, description: "Optional bot username for mentions"}
      },
      required: ["command_text"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        name: %{type: :string},
        raw_command: %{type: :string},
        subcommand: %{type: :string},
        args: %{type: :array, items: %{type: :string}},
        named_args: %{type: :object},
        flags: %{type: :array, items: %{type: :string}},
        bot_username: %{type: :string}
      }
    }

  @impl true
  def handler(params, _agent) do
    command_text = params[:command_text] || params["command_text"] || ""
    bot_username = params[:bot_username] || params["bot_username"] || nil

    result =
      python variables: %{command_text: command_text, bot_username: bot_username} do
        ~PY"""
        from lux.telegram.commands import CommandParser
        parsed = CommandParser.parse(command_text, bot_username)
        {
            "name": str(parsed.name),
            "raw_command": str(parsed.raw_command),
            "subcommand": str(parsed.subcommand) if parsed.subcommand else None,
            "args": list(parsed.args),
            "named_args": dict(parsed.named_args),
            "flags": list(parsed.flags),
            "bot_username": str(parsed.bot_username) if parsed.bot_username else None
        }
        """
      end

    {:ok, result}
  rescue
    e in RuntimeError ->
      {:error, "Command routing parsing failed: #{Exception.message(e)}"}
  end
end
