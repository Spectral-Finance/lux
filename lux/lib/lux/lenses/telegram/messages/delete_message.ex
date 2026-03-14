defmodule Lux.Lenses.Telegram.Messages.DeleteMessage do
  @moduledoc """
  A lens for deleting messages via the Telegram Bot API.

  This lens provides a simple interface for deleting messages with:
  - Required parameters (chat_id, message_id)
  - Rate limit handling (429 responses)
  - Clean response structure

  ## Limitations

  A message can only be deleted if it was sent less than 48 hours ago.
  Bots can delete outgoing messages in private chats, groups, and supergroups.
  Bots can delete incoming messages in private chats.
  Bots granted can_post_messages permissions can delete outgoing messages in channels.

  ## Examples

      iex> DeleteMessage.focus(%{
      ...>   chat_id: 123_456_789,
      ...>   message_id: 42
      ...> })
      {:ok, %{deleted: true}}
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Delete Telegram Message",
    description: "Deletes a message from a chat via the Telegram Bot API",
    url: Telegram.api_url("deleteMessage"),
    method: :post,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
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
  Transforms the Telegram API response into a clean format.
  """
  @impl true
  def after_focus(%{"ok" => true, "result" => true}) do
    {:ok, %{deleted: true}}
  end

  def after_focus(%{"ok" => false, "error_code" => 429, "parameters" => %{"retry_after" => retry_after}} = error) do
    {:error, %{
      reason: :rate_limited,
      retry_after: retry_after,
      description: error["description"]
    }}
  end

  def after_focus(%{"ok" => false, "description" => description, "error_code" => code}) do
    {:error, %{reason: :api_error, error_code: code, description: description}}
  end

  def after_focus(%{"description" => description}) do
    {:error, %{reason: :api_error, description: description}}
  end
end
