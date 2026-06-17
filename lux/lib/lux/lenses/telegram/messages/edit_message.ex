defmodule Lux.Lenses.Telegram.Messages.EditMessage do
  @moduledoc """
  A lens for editing text and game messages.
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Telegram Edit Message Text",
    description: "Edits text and game messages. On success, the edited Message is returned.",
    url: "https://api.telegram.org/bot<token>/editMessageText",
    method: :post,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:integer, :string],
          description: "Unique identifier for the target chat or username of the target channel."
        },
        message_id: %{
          type: :integer,
          description: "Identifier of the message to edit."
        },
        text: %{
          type: :string,
          description: "New text of the message, 1-4096 characters."
        },
        parse_mode: %{
          type: :string,
          description: "Mode for parsing entities in the message text.",
          enum: ["MarkdownV2", "HTML", "Markdown"]
        },
        reply_markup: %{
          type: :object,
          description: "A JSON-serialized object for an inline keyboard."
        }
      },
      required: ["chat_id", "message_id", "text"]
    }

  @doc """
  Transforms the Telegram API response.
  """
  @impl true
  def after_focus(%{"ok" => true, "result" => result}) do
    {:ok, result}
  end

  def after_focus(%{"ok" => false, "description" => description}) do
    {:error, description}
  end
  
  def after_focus(other), do: {:error, other}
end
