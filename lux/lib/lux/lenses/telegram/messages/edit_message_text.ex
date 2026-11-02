defmodule Lux.Lenses.Telegram.Messages.EditMessageText do
  @moduledoc """
  A lens for editing text of existing Telegram messages.
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Edit Telegram Message Text",
    description: "Edits text and game messages sent by the bot or via the bot",
    url: "https://api.telegram.org/bot/editMessageText",
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
        message_id: %{
          type: :integer,
          description: "Identifier of the message to edit"
        },
        text: %{
          type: :string,
          description: "New text of the message",
          maxLength: 4096
        },
        parse_mode: %{
          type: :string,
          enum: ["MarkdownV2", "HTML", "Markdown"]
        }
      },
      required: ["chat_id", "message_id", "text"]
    }

  @impl true
  def before_focus(params) do
    payload = %{
      "chat_id" => to_string(params.chat_id),
      "message_id" => params.message_id,
      "text" => params.text
    }

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
       text: result["text"],
       edit_date: result["edit_date"]
     }}
  end

  def after_focus(other), do: {:ok, other}
end
