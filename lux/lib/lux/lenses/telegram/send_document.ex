defmodule Lux.Lenses.Telegram.SendDocument do
  @moduledoc """
  Lens for sending documents via the Telegram Bot API.

  ## Examples

      Lux.Lenses.Telegram.SendDocument.focus(%{
        chat_id: "123456",
        document: "https://example.com/file.pdf",
        caption: "Important document"
      })
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Send Telegram Document",
    description: "Sends a document file to a chat or channel",
    url: "https://api.telegram.org/bot:token/sendDocument",
    method: :post,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: :string,
          description: "Unique identifier for the target chat or username"
        },
        document: %{
          type: :string,
          description: "Document to send. Pass a file_id or HTTP URL"
        },
        caption: %{type: :string, description: "Document caption"}
      },
      required: ["chat_id", "document"]
    }

  def before_focus(params) do
    Map.put(params, :token, Telegram.token())
  end

  @impl true
  def after_focus(%{"ok" => true, "result" => result}) do
    {:ok,
     %{
       message_id: result["message_id"],
       document: result["document"],
       caption: result["caption"]
     }}
  end

  def after_focus(%{"ok" => false, "description" => description}), do: {:error, description}
  def after_focus(other), do: {:error, other}
end
