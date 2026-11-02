defmodule Lux.Lenses.Telegram.Media.SendPhoto do
  @moduledoc """
  A lens for sending photos via Telegram Bot API using photo URL or file_id.
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Send Telegram Photo",
    description: "Sends photos to Telegram chats or channels",
    url: "https://api.telegram.org/bot/sendPhoto",
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
        photo: %{
          type: :string,
          description: "Photo to send. Pass file_id or HTTP URL"
        },
        caption: %{
          type: :string,
          description: "Photo caption (0-1024 characters)",
          maxLength: 1024
        },
        parse_mode: %{
          type: :string,
          enum: ["MarkdownV2", "HTML", "Markdown"]
        }
      },
      required: ["chat_id", "photo"]
    }

  @impl true
  def before_focus(params) do
    payload = %{
      "chat_id" => to_string(params.chat_id),
      "photo" => params.photo
    }

    payload =
      if Map.get(params, :caption) do
        Map.put(payload, "caption", params.caption)
      else
        payload
      end

    payload =
      if Map.get(params, :parse_mode) do
        Map.put(payload, "parse_mode", params.parse_mode)
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
       photo: result["photo"],
       caption: result["caption"]
     }}
  end

  def after_focus(other), do: {:ok, other}
end
