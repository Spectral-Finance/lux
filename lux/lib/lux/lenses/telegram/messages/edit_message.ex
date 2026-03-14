defmodule Lux.Lenses.Telegram.Messages.EditMessage do
  @moduledoc """
  A lens for editing text messages via the Telegram Bot API.

  This lens provides a simple interface for editing previously sent messages with:
  - Required parameters (chat_id, message_id, text)
  - Optional formatting controls
  - Rate limit handling (429 responses)
  - Clean response structure

  ## Examples

      iex> EditMessage.focus(%{
      ...>   chat_id: 123_456_789,
      ...>   message_id: 42,
      ...>   text: "Updated message text"
      ...> })
      {:ok, %{
        message_id: 42,
        chat_id: 123_456_789,
        text: "Updated message text",
        date: 1_234_567_890,
        edit_date: 1_234_567_900
      }}
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Edit Telegram Message",
    description: "Edits a text message in a chat via the Telegram Bot API",
    url: Telegram.api_url("editMessageText"),
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
          description: "Identifier of the message to edit"
        },
        text: %{
          type: :string,
          description: "New text of the message, 1-4096 characters"
        },
        parse_mode: %{
          type: :string,
          description: "Mode for parsing entities in the message text",
          enum: ["Markdown", "MarkdownV2", "HTML"]
        },
        disable_web_page_preview: %{
          type: :boolean,
          description: "Disables link previews for links in this message"
        }
      },
      required: ["chat_id", "message_id", "text"]
    }

  @doc """
  Transforms the Telegram API response into a clean format.
  """
  @impl true
  def after_focus(%{"ok" => true, "result" => result}) do
    {:ok, %{
      message_id: result["message_id"],
      chat_id: result["chat"]["id"],
      text: result["text"],
      date: result["date"],
      edit_date: result["edit_date"]
    }}
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
