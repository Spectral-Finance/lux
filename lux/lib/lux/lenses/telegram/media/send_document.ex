defmodule Lux.Lenses.Telegram.Media.SendDocument do
  @moduledoc \"\"\"
  A lens for sending documents via Telegram Bot API.
  Currently supports sending documents by URL or file_id.
  \"\"\"

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Send Telegram Document",
    description: "Sends a document to a chat.",
    url: "https://api.telegram.org/bot/sendDocument",
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
        document: %{
          type: :string,
          description: "Document to send. Pass a file_id as String to send a document that exists on the Telegram servers, or pass an HTTP URL as a String for Telegram to get a document from the Internet"
        },
        caption: %{
          type: :string,
          description: "Document caption, 0-1024 characters after entities parsing"
        }
      },
      required: ["chat_id", "document"]
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
