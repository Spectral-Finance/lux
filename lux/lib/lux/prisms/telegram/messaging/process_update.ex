defmodule Lux.Prisms.Telegram.Messaging.ProcessUpdate do
  @moduledoc """
  Prism for classifying and transforming Telegram Bot API updates offline.
  """

  use Lux.Prism,
    name: "Process Telegram Update",
    description:
      "Classifies Telegram updates, parses commands, formats text, and extracts thread/reply/callback context",
    input_schema: %{
      type: :object,
      properties: %{
        update: %{type: :object, description: "Telegram Bot API update"},
        bot_username: %{
          type: :string,
          description: "Optional bot username for command mention filtering"
        }
      },
      required: ["update"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        update_type: %{type: :string, description: "Telegram update field type"},
        message_type: %{type: :string, description: "Normalized message type"},
        command: %{type: :object, description: "Parsed command and arguments"},
        formatting: %{type: :object, description: "MarkdownV2 and HTML escaped text"},
        thread: %{type: :object, description: "Thread and message context"},
        reply: %{type: :object, description: "Reply context"},
        callback: %{type: :object, description: "Callback query context"},
        route: %{type: :object, description: "Suggested route action"}
      },
      required: ["update_type", "message_type", "formatting", "thread", "route"]
    }

  alias Lux.Integrations.Telegram.MessageProcessor

  def handler(%{update: update} = input, _ctx) do
    MessageProcessor.process_update(update, bot_username: Map.get(input, :bot_username, ""))
  end

  def handler(%{"update" => update} = input, _ctx) do
    MessageProcessor.process_update(update, bot_username: Map.get(input, "bot_username", ""))
  end

  def handler(_input, _ctx), do: {:error, "Missing update"}
end
