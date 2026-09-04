defmodule Lux.Lenses.Telegram.EditMessageText do
  @moduledoc """
  Lens for editing message text via Telegram Bot API.
  """

  use Lux.Telegram.Lens,
    name: "EditMessageText",
    description: "Edits text of a message in a Telegram chat or inline message",
    url: "https://api.telegram.org/bot/editMessageText",
    method: :post,
    schema: %{
      type: :object,
      properties: %{
        chat_id: %{type: [:string, :integer], description: "Target chat ID or username"},
        message_id: %{type: :integer, description: "ID of message to edit"},
        inline_message_id: %{type: :string, description: "ID of inline message"},
        text: %{type: :string, description: "New text message"},
        parse_mode: %{type: :string, description: "Formatting mode"}
      },
      required: ["text"]
    }
end
