defmodule Lux.Lenses.Telegram.Messages.DeleteMessage do
  @moduledoc """
  A lens for deleting messages in Telegram chats.
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Delete Telegram Message",
    description: "Deletes a message in a Telegram chat",
    url: "https://api.telegram.org/bot/deleteMessage",
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
          description: "Identifier of the message to delete"
        }
      },
      required: ["chat_id", "message_id"]
    }

  @impl true
  def before_focus(params) do
    {:ok, %{"chat_id" => to_string(params.chat_id), "message_id" => params.message_id}}
  end

  @impl true
  def after_focus(%{"ok" => true, "result" => true}) do
    {:ok, %{deleted: true}}
  end

  def after_focus(other), do: {:ok, other}
end
