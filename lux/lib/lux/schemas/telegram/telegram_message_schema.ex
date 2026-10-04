defmodule Lux.Schemas.Telegram.TelegramMessageSchema do
  @moduledoc """
  Schema definition for Telegram message signals.
  """

  use Lux.SignalSchema,
    name: "Telegram Message Schema",
    description: "Schema for incoming and analyzed Telegram messages",
    schema: %{
      type: :object,
      properties: %{
        chat_id: %{type: :integer, description: "Telegram chat identifier"},
        message_id: %{type: :integer, description: "Unique message identifier"},
        user_id: %{type: :integer, description: "Sender Telegram user ID"},
        username: %{type: :string, description: "Sender Telegram username"},
        text: %{type: :string, description: "Message body text"},
        intent: %{type: :string, description: "Classified intent category"},
        urgency: %{type: :string, description: "Classified urgency level"},
        sentiment_score: %{type: :number, description: "Sentiment polarity score"},
        extracted_entities: %{type: :object, description: "Extracted crypto entities"},
        timestamp: %{type: :integer, description: "Message unix timestamp"}
      },
      required: ["chat_id", "message_id", "text"]
    }
end
