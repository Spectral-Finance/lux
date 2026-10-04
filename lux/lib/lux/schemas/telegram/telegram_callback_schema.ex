defmodule Lux.Schemas.Telegram.TelegramCallbackSchema do
  @moduledoc """
  Schema definition for Telegram inline button callback signals.
  """

  use Lux.SignalSchema,
    name: "Telegram Callback Schema",
    description: "Schema for incoming inline button click callback queries",
    schema: %{
      type: :object,
      properties: %{
        callback_query_id: %{type: :string, description: "Unique callback query identifier"},
        user_id: %{type: :integer, description: "Sender Telegram user ID"},
        chat_id: %{type: :integer, description: "Chat identifier"},
        message_id: %{type: :integer, description: "Message containing the inline button"},
        data: %{type: :string, description: "Raw callback data payload"},
        action: %{type: :string, description: "Decoded action name"},
        target: %{type: :string, description: "Target entity/resource"},
        item_id: %{type: :string, description: "Target item ID"}
      },
      required: ["callback_query_id", "user_id", "data"]
    }
end
