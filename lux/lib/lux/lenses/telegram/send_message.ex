defmodule Lux.Lenses.Telegram.SendMessage do
  @moduledoc """
  Lens for sending text messages via the Telegram Bot API.

  ## Examples

      Lux.Lenses.Telegram.SendMessage.focus(%{chat_id: "123456789", text: "Hello World"})
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Send Telegram Message",
    description: "Sends a text message to a specific chat or channel",
    url: "https://api.telegram.org/bot:token/sendMessage",
    method: :post,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: :string,
          description:
            "Unique identifier for the target chat or username of the target channel (in the format @channelusername)"
        },
        text: %{type: :string, description: "Text of the message to be sent"},
        parse_mode: %{
          type: :string,
          description: "Mode for parsing entities in the message text",
          enum: ["MarkdownV2", "HTML", "Markdown"]
        },
        reply_markup: %{
          type: :object,
          description: "Additional interface options (JSON object)"
        }
      },
      required: ["chat_id", "text"]
    }

  def before_focus(params) do
    Map.put(params, :token, Telegram.token())
  end

  @impl true
  def after_focus(%{"ok" => true, "result" => result}) do
    {:ok,
     %{
       message_id: result["message_id"],
       chat: result["chat"],
       text: result["text"]
     }}
  end

  def after_focus(%{"ok" => false, "description" => description}), do: {:error, description}
  def after_focus(other), do: {:error, other}
end
