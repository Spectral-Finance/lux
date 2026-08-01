defmodule Lux.Lenses.Telegram.Messages.EditMessage do
  @moduledoc \"\"\"
  A lens for editing text messages via Telegram Bot API.
  \"\"\"

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Edit Telegram Message",
    description: "Edits a text message previously sent by the bot.",
    url: "https://api.telegram.org/bot/editMessageText",
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
        message_id: %{
          type: :integer,
          description: "Identifier of the message to edit"
        },
        text: %{
          type: :string,
          description: "New text of the message"
        },
        parse_mode: %{
          type: :string,
          description: "Mode for parsing entities"
        },
        reply_markup: %{
          type: :object,
          description: "A JSON-serialized object for an inline keyboard."
        }
      },
      required: ["chat_id", "message_id", "text"]
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
