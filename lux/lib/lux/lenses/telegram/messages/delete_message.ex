defmodule Lux.Lenses.Telegram.Messages.DeleteMessage do
  @moduledoc """
  A lens for deleting messages in Telegram chats.

  ## Examples

      iex> DeleteMessage.focus(%{
      ...>   chat_id: "123456789",
      ...>   message_id: 42
      ...> })
      {:ok, %{deleted: true}}
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
          description: "Unique identifier for the target chat or username of the target channel"
        },
        message_id: %{
          type: :integer,
          description: "Identifier of the message to delete"
        }
      },
      required: ["chat_id", "message_id"]
    }

  @doc """
  Transforms the Telegram API response into a deletion confirmation.
  """
  @impl true
  def after_focus(%{"ok" => true, "result" => true}) do
    {:ok, %{deleted: true}}
  end

  def after_focus(%{"ok" => false, "description" => description}) do
    {:error, description}
  end

  def after_focus(%{"description" => description}) do
    {:error, description}
  end

  def after_focus(error) do
    {:error, error}
  end
end
