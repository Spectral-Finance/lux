defmodule Lux.Prisms.Telegram.Processing.FormatText do
  @moduledoc """
  Prism that escapes text for Telegram MarkdownV2 or HTML parse modes.
  """

  use Lux.Prism,
    name: "Format Telegram Text",
    description: "Escapes text for Telegram MarkdownV2 or HTML formatting",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{type: :string, description: "Text to escape"},
        mode: %{
          type: :string,
          enum: ["MarkdownV2", "HTML", "plain"],
          description: "Telegram parse mode"
        }
      },
      required: ["text"]
    }

  alias Lux.Integrations.Telegram.MessageProcessing

  def handler(params, _context) when is_map(params) do
    text = Map.get(params, :text, Map.get(params, "text", ""))
    mode = Map.get(params, :mode, Map.get(params, "mode", "plain"))
    {:ok, MessageProcessing.format_text(text, mode)}
  end
end
