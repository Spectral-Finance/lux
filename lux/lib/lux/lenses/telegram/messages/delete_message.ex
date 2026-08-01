defmodule Lux.Lenses.Telegram.Messages.DeleteMessage do
  @moduledoc \"\"\"
  A lens for deleting messages via Telegram Bot API.
  \"\"\"

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Delete Telegram Message",
    description: "Deletes a message previously sent by the bot.",
    url: "https://api.telegram.org/bot/deleteMessage",
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
          description: "Identifier of the message to delete"
        }
      },
      required: ["chat_id", "message_id"]
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
