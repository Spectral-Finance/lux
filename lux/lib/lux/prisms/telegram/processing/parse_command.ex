defmodule Lux.Prisms.Telegram.Processing.ParseCommand do
  @moduledoc """
  Prism that parses Telegram slash commands with quoted argument support.
  """

  use Lux.Prism,
    name: "Parse Telegram Command",
    description:
      "Parses a Telegram slash command into command name, optional bot mention, raw args, tokenized args, and addressed? flag",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{type: :string, description: "Message text to parse"},
        bot_username: %{type: :string, description: "Optional bot username for mention filtering"}
      },
      required: ["text"]
    }

  alias Lux.Integrations.Telegram.MessageProcessing

  def handler(%{text: text} = params, _context),
    do: {:ok, MessageProcessing.parse_command(text, Map.get(params, :bot_username))}

  def handler(%{"text" => text} = params, _context),
    do: {:ok, MessageProcessing.parse_command(text, Map.get(params, "bot_username"))}

  def handler(_params, _context), do: {:error, "Missing command text"}
end
