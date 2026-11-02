defmodule Lux.Lenses.Telegram.Media.SendDocument do
  @moduledoc """
  A lens for sending general files and documents via Telegram Bot API.
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Send Telegram Document",
    description: "Sends general files and documents to Telegram chats",
    url: "https://api.telegram.org/bot/sendDocument",
    method: :post,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: :string,
          description: "Target chat unique identifier"
        },
        document: %{
          type: :string,
          description: "File to send. Pass file_id or HTTP URL"
        },
        caption: %{
          type: :string,
          description: "Document caption (0-1024 characters)",
          maxLength: 1024
        }
      },
      required: ["chat_id", "document"]
    }

  @impl true
  def before_focus(params) do
    payload = %{
      "chat_id" => to_string(params.chat_id),
      "document" => params.document
    }

    payload =
      if Map.get(params, :caption) do
        Map.put(payload, "caption", params.caption)
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
       document: result["document"]
     }}
  end

  def after_focus(other), do: {:ok, other}
end
