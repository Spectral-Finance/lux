defmodule Lux.Lenses.Telegram.Messages.SendMessage do
  @moduledoc """
  A lens for sending text messages via the Telegram Bot API.

  This lens provides a simple interface for sending messages with:
  - Required parameters (chat_id, text)
  - Optional formatting and notification controls
  - Rate limit handling (429 responses)
  - Clean response structure

  ## Examples

      iex> SendMessage.focus(%{
      ...>   chat_id: 123_456_789,
      ...>   text: "Hello from Lux!"
      ...> })
      {:ok, %{
        message_id: 456,
        chat_id: 123_456_789,
        text: "Hello from Lux!",
        date: 1_234_567_890
      }}

      iex> SendMessage.focus(%{
      ...>   chat_id: 123_456_789,
      ...>   text: "*Bold text*",
      ...>   parse_mode: "MarkdownV2"
      ...> })
      {:ok, %{
        message_id: 457,
        chat_id: 123_456_789,
        text: "*Bold text*",
        date: 1_234_567_890
      }}
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Send Telegram Message",
    description: "Sends a text message to a chat via the Telegram Bot API",
    url: Telegram.api_url("sendMessage"),
    method: :post,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat or username of the target channel (in the format @channelusername)"
        },
        text: %{
          type: :string,
          description: "Text of the message to be sent, 1-4096 characters"
        },
        parse_mode: %{
          type: :string,
          description: "Mode for parsing entities in the message text",
          enum: ["Markdown", "MarkdownV2", "HTML"]
        },
        disable_web_page_preview: %{
          type: :boolean,
          description: "Disables link previews for links in this message"
        },
        disable_notification: %{
          type: :boolean,
          description: "Sends the message silently. Users will receive a notification with no sound."
        },
        protect_content: %{
          type: :boolean,
          description: "Protects the contents of the sent message from forwarding and saving"
        },
        reply_to_message_id: %{
          type: :integer,
          description: "If the message is a reply, ID of the original message"
        }
      },
      required: ["chat_id", "text"]
    }

  @doc """
  Transforms the Telegram API response into a clean format.

  Handles successful responses, error responses, and rate limiting (429).
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
