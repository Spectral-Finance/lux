defmodule Lux.Lenses.Telegram.Keyboards.SendInlineKeyboard do
  @moduledoc """
  A lens for sending messages with inline keyboards via the Telegram Bot API.

  Inline keyboards are buttons attached to messages that can trigger callback queries,
  open URLs, or switch to inline mode.

  ## Keyboard Layout

  The `reply_markup` parameter should contain an `inline_keyboard` field, which is
  an array of arrays of button objects. Each inner array represents a row of buttons.

  ## Button Types

  Each button must have a `text` field and exactly one optional field:
  - `callback_data` - Data sent in a callback query when button is pressed
  - `url` - HTTP/HTTPS URL to open
  - `switch_inline_query` - Switches to inline mode in the current chat

  ## Examples

      iex> SendInlineKeyboard.focus(%{
      ...>   chat_id: 123_456_789,
      ...>   text: "Choose an option:",
      ...>   reply_markup: %{
      ...>     inline_keyboard: [
      ...>       [
      ...>         %{text: "Option 1", callback_data: "opt1"},
      ...>         %{text: "Option 2", callback_data: "opt2"}
      ...>       ],
      ...>       [
      ...>         %{text: "Visit Website", url: "https://example.com"}
      ...>       ]
      ...>     ]
      ...>   }
      ...> })
      {:ok, %{
        message_id: 456,
        chat_id: 123_456_789,
        text: "Choose an option:",
        date: 1_234_567_890
      }}
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Send Telegram Inline Keyboard",
    description: "Sends a message with an inline keyboard via the Telegram Bot API",
    url: Telegram.api_url("sendMessage"),
    method: :post,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat or username of the target channel"
        },
        text: %{
          type: :string,
          description: "Text of the message to be sent"
        },
        reply_markup: %{
          type: :object,
          description: "InlineKeyboardMarkup object with inline_keyboard array of button rows",
          properties: %{
            inline_keyboard: %{
              type: :array,
              description: "Array of button rows, each row is an array of InlineKeyboardButton objects",
              items: %{
                type: :array,
                items: %{
                  type: :object,
                  properties: %{
                    text: %{type: :string, description: "Label text on the button"},
                    callback_data: %{type: :string, description: "Data sent in callback query when pressed (1-64 bytes)"},
                    url: %{type: :string, description: "HTTP/HTTPS URL to open when pressed"}
                  },
                  required: ["text"]
                }
              }
            }
          },
          required: ["inline_keyboard"]
        },
        parse_mode: %{
          type: :string,
          description: "Mode for parsing entities in the message text",
          enum: ["Markdown", "MarkdownV2", "HTML"]
        },
        disable_notification: %{
          type: :boolean,
          description: "Sends the message silently"
        }
      },
      required: ["chat_id", "text", "reply_markup"]
    }

  @doc """
  Transforms the Telegram API response into a clean format.
  """
  @impl true
  def after_focus(%{"ok" => true, "result" => result}) do
    {:ok, %{
      message_id: result["message_id"],
      chat_id: result["chat"]["id"],
      text: result["text"],
      date: result["date"]
    }}
  end

  def after_focus(%{"ok" => false, "error_code" => 429, "parameters" => %{"retry_after" => retry_after}} = error) do
    {:error, %{
      reason: :rate_limited,
      retry_after: retry_after,
      description: error["description"]
    }}
  end

  def after_focus(%{"ok" => false, "description" => description, "error_code" => code}) do
    {:error, %{reason: :api_error, error_code: code, description: description}}
  end

  def after_focus(%{"description" => description}) do
    {:error, %{reason: :api_error, description: description}}
  end
end
