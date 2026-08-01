defmodule Lux.Lenses.Telegram.Messages.SendMessage do
  @moduledoc \"\"\"
  A lens for sending text messages via Telegram Bot API.
  \"\"\"

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Send Telegram Message",
    description: "Sends a text message to a chat.",
    url: "https://api.telegram.org/bot/sendMessage",
    method: :post,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: :string,
          description: "Unique identifier for the target chat"
        },
        text: %{
          type: :string,
          description: "Text of the message to be sent"
        },
        parse_mode: %{
          type: :string,
          description: "Mode for parsing entities (e.g. MarkdownV2 or HTML)"
        },
        reply_markup: %{
          type: :object,
          description: "Additional interface options. A JSON-serialized object for an inline keyboard, custom reply keyboard, instructions to remove reply keyboard or to force a reply from the user."
        }
      },
      required: ["chat_id", "text"]
    }

  @impl true
  def after_focus(%{"ok" => true, "result" => result}) do
    {:ok, result}
  end

  def after_focus(%{"ok" => false, "description" => description} = error) do
    {:error, error}
  end

  def after_focus(error) do
    {:error, error}
  end
end
