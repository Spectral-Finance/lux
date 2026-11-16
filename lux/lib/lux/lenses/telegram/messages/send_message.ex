defmodule Lux.Lenses.Telegram.Messages.SendMessage do
  @moduledoc """
  A lens for sending messages to Telegram chats and channels via the Telegram Bot API.

  Supports:
  - Formatted text (MarkdownV2, HTML, Markdown)
  - Inline keyboards and custom keyboards (reply_markup)
  - Message replies (reply_to_message_id)
  - Silent notifications (disable_notification)
  - Web page preview controls (disable_web_page_preview)

  ## Examples

      iex> SendMessage.focus(%{
      ...>   chat_id: "123456789",
      ...>   text: "Hello from Lux Agent!",
      ...>   parse_mode: "HTML"
      ...> })
      {:ok, %{
        message_id: 42,
        chat_id: 123456789,
        text: "Hello from Lux Agent!",
        date: 1700000000
      }}
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Send Telegram Message",
    description: "Sends a text message with optional formatting and keyboards to a Telegram chat",
    url: "https://api.telegram.org/bot/sendMessage",
    method: :post,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: :string,
          description: "Target chat ID or channel username (e.g. '@channelusername')"
        },
        text: %{
          type: :string,
          description: "Text of the message to be sent (1-4096 characters)"
        },
        parse_mode: %{
          type: :string,
          description: "Mode for parsing entities in the message text",
          enum: ["MarkdownV2", "HTML", "Markdown"]
        },
        disable_web_page_preview: %{
          type: :boolean,
          description: "Disables link previews for links in this message"
        },
        disable_notification: %{
          type: :boolean,
          description: "Sends the message silently (users receive a notification with no sound)"
        },
        reply_to_message_id: %{
          type: :integer,
          description: "If the message is a reply, ID of the original message"
        },
        reply_markup: %{
          type: :object,
          description: "Inline keyboard, custom reply keyboard, or force reply markup"
        }
      },
      required: ["chat_id", "text"]
    }

  @doc """
  Transforms the Telegram API response into a structured message payload.
  """
  @impl true
  def after_focus(%{"ok" => true, "result" => result}) do
    {:ok,
     %{
       message_id: result["message_id"],
       chat_id: get_in(result, ["chat", "id"]),
       text: result["text"],
       date: result["date"],
       from: extract_sender(result["from"])
     }}
  end

  def after_focus(%{"ok" => false, "description" => description}) do
    {:error, description}
  end

  def after_focus(%{"description" => description}) do
    {:error, description}
  end

  def after_focus(error) do
    {:error, error}
  end

  defp extract_sender(nil), do: nil

  defp extract_sender(from) do
    %{
      id: from["id"],
      is_bot: from["is_bot"],
      first_name: from["first_name"],
      username: from["username"]
    }
  end
end
