defmodule Lux.Lenses.Telegram.Messages.SendMessage do
  @moduledoc """
  A lens for sending text messages via Telegram Bot API.

  ## Examples

      iex> SendMessage.focus(%{
      ...>   chat_id: 123456789,
      ...>   text: "Hello from Lux agent framework!"
      ...> })
      {:ok, %{
        message_id: 456,
        text: "Hello from Lux agent framework!"
      }}
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Send Telegram Message",
    description: "Sends text messages to Telegram chats or channels",
    url: "https://api.telegram.org/bot/sendMessage",
    method: :post,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: :string,
          description: "Target chat unique identifier or username of target channel"
        },
        text: %{
          type: :string,
          description: "Text of the message to be sent (up to 4096 characters)",
          maxLength: 4096
        },
        parse_mode: %{
          type: :string,
          enum: ["MarkdownV2", "HTML", "Markdown"],
          description: "Mode for parsing entities in the message text"
        },
        disable_web_page_preview: %{
          type: :boolean,
          description: "Disables link previews for links in this message"
        }
      },
      required: ["chat_id", "text"]
    }

  @impl true
  def before_focus(params) do
    payload = %{
      "chat_id" => to_string(params.chat_id),
      "text" => params.text
    }

    payload =
      if Map.get(params, :parse_mode) do
        Map.put(payload, "parse_mode", params.parse_mode)
      else
        payload
      end

    payload =
      if Map.get(params, :disable_web_page_preview) != nil do
        Map.put(payload, "disable_web_page_preview", params.disable_web_page_preview)
      else
        payload
      end

    {:ok, payload}
  end

  @impl true
  def after_focus(%{"ok" => true, "result" => result}) do
    {:ok,
     %{
       message_id: result["message_id"],
       chat_id: get_in(result, ["chat", "id"]),
       text: result["text"],
       date: result["date"]
     }}
  end

  def after_focus(other), do: {:ok, other}
end
