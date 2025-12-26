defmodule Lux.Lenses.Telegram.DeleteMessage do
  @moduledoc """
  Lens for deleting messages via the Telegram Bot API.

  ## Examples

      Lux.Lenses.Telegram.DeleteMessage.focus(%{chat_id: "123456", message_id: 42})
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Delete Telegram Message",
    description: "Deletes a message, including service messages, with limitations",
    url: "https://api.telegram.org/bot:token/deleteMessage",
    method: :post,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: :string,
          description: "Unique identifier for the target chat or username of the target channel"
        },
        message_id: %{type: :integer, description: "Identifier of the message to delete"}
      },
      required: ["chat_id", "message_id"]
    }

  def before_focus(params) do
    Map.put(params, :token, Telegram.token())
  end

  @impl true
  def after_focus(%{"ok" => true, "result" => true}), do: {:ok, true}
  def after_focus(%{"ok" => false, "description" => description}), do: {:error, description}
  def after_focus(other), do: {:error, other}
end
