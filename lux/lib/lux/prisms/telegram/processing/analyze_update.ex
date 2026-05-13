defmodule Lux.Prisms.Telegram.Processing.AnalyzeUpdate do
  @moduledoc """
  Prism that classifies and normalizes a Telegram Bot API update.
  """

  use Lux.Prism,
    name: "Analyze Telegram Update",
    description:
      "Classifies Telegram updates, extracts command/deep-link/reply/thread/callback context, and returns an agent-friendly map",
    input_schema: %{
      type: :object,
      properties: %{
        update: %{type: :object, description: "Raw Telegram Bot API update"},
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
        type: %{type: :string, description: "Detected update/message type"},
        chat_id: %{type: [:integer, :string]},
        user_id: %{type: :integer},
        text: %{type: :string},
        command: %{type: :object},
        thread: %{type: :object},
        reply: %{type: :object},
        callback_query: %{type: :object},
        deep_link: %{type: :object}
      }
    }

  alias Lux.Integrations.Telegram.MessageProcessing

  def handler(%{update: update} = params, _context) do
    {:ok, MessageProcessing.analyze_update(update, bot_username: Map.get(params, :bot_username))}
  end

  def handler(%{"update" => update} = params, _context) do
    {:ok, MessageProcessing.analyze_update(update, bot_username: Map.get(params, "bot_username"))}
  end

  def handler(_params, _context), do: {:error, "Missing Telegram update"}
end
