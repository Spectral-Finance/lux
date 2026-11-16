defmodule Lux.Lenses.Telegram.Messages.EditMessage do
  @moduledoc """
  A lens for editing text and game messages sent by the bot or through the bot.

  ## Examples

      iex> EditMessage.focus(%{
      ...>   chat_id: "123456789",
      ...>   message_id: 42,
      ...>   text: "Updated text from Lux Agent!",
      ...>   parse_mode: "HTML"
      ...> })
      {:ok, %{
        message_id: 42,
        chat_id: 123456789,
        text: "Updated text from Lux Agent!",
        edit_date: 1700000050
      }}
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Edit Telegram Message",
    description: "Edits text and game messages in a Telegram chat or inline message",
    url: "https://api.telegram.org/bot/editMessageText",
    method: :post,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: :string,
          description:
            "Required if inline_message_id is not specified. Unique identifier for the target chat"
        },
        message_id: %{
          type: :integer,
          description:
            "Required if inline_message_id is not specified. Identifier of the message to edit"
        },
        inline_message_id: %{
          type: :string,
          description:
            "Required if chat_id and message_id are not specified. Identifier of the inline message"
        },
        text: %{
          type: :string,
          description: "New text of the message (1-4096 characters)"
        },
        parse_mode: %{
          type: :string,
          description: "Mode for parsing entities in the message text",
          enum: ["MarkdownV2", "HTML", "Markdown"]
        },
        disable_web_page_preview: %{
          type: :boolean,
          description: "Disables link previews for links in this message"
        },
        reply_markup: %{
          type: :object,
          description: "An InlineKeyboardMarkup object"
        }
      },
      required: ["text"]
    }

  @doc """
  Transforms the Telegram API response into a structured message payload.
  """
  @impl true
  def after_focus(%{"ok" => true, "result" => true}) do
    {:ok, %{success: true}}
  end

  def after_focus(%{"ok" => true, "result" => result}) when is_map(result) do
    {:ok,
     %{
       message_id: result["message_id"],
       chat_id: get_in(result, ["chat", "id"]),
       text: result["text"],
       edit_date: result["edit_date"]
     }}
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
