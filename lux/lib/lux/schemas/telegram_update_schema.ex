defmodule Lux.Schemas.TelegramUpdateSchema do
  @moduledoc """
  Schema for validating incoming Telegram update signals.
  """
  use Lux.SignalSchema,
    name: "telegram_update",
    version: "1.0.0",
    description: "Represents an incoming Telegram update",
    format: :json,
    compatibility: :full,
    schema: %{
      type: :object,
      properties: %{
        update_id: %{
          type: :integer,
          description: "The update's unique identifier"
        },
        message: %{type: :object},
        edited_message: %{type: :object},
        channel_post: %{type: :object},
        edited_channel_post: %{type: :object},
        inline_query: %{type: :object},
        chosen_inline_result: %{type: :object},
        callback_query: %{type: :object},
        shipping_query: %{type: :object},
        pre_checkout_query: %{type: :object},
        poll: %{type: :object},
        poll_answer: %{type: :object},
        my_chat_member: %{type: :object},
        chat_member: %{type: :object},
        chat_join_request: %{type: :object}
      },
      required: ["update_id"]
    }
end
