defmodule Lux.Lenses.Telegram.EditMessageText do
  @moduledoc """
  Lens for editing existing text messages on Telegram.

  ## Examples

      Lux.Lenses.Telegram.EditMessageText.focus(%{chat_id: "123456", message_id: 123, text: "Updated text"})
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Edit Telegram Message Text",
    description: "Edits the text of a previously sent message",
    url: "https://api.telegram.org/bot:token/editMessageText",
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
        message_id: %{type: :integer, description: "Identifier of the message to edit"},
        text: %{type: :string, description: "New text of the message"}
      },
      required: ["chat_id", "message_id", "text"]
    }

  def before_focus(params) do
    Map.put(params, :token, Telegram.token())
  end

  @impl true
  def after_focus(%{"ok" => true, "result" => true}), do: {:ok, %{edited: true}}

  def after_focus(%{"ok" => true, "result" => result}) when is_map(result) do
    {:ok,
     %{
       edited: true,
       message_id: result["message_id"],
       text: result["text"],
       date: result["date"]
     }}
  end

  def after_focus(%{"ok" => false, "description" => description}), do: {:error, description}
  def after_focus(other), do: {:error, other}
end
