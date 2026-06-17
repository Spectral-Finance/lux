defmodule Lux.Lenses.Telegram.Messages.SendMessage do
  @moduledoc """
  A lens for sending text messages to Telegram chats.
  Supports custom inline keyboards, parse modes, and more.
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Telegram Send Message",
    description: "Sends text messages. On success, the sent Message is returned.",
    url: "https://api.telegram.org/bot<token>/sendMessage",
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
        text: %{
          type: :string,
          description: "Text of the message to be sent, 1-4096 characters."
        },
        parse_mode: %{
          type: :string,
          description: "Mode for parsing entities in the message text. (MarkdownV2, HTML, Markdown)",
          enum: ["MarkdownV2", "HTML", "Markdown"]
        },
        reply_markup: %{
          type: :object,
          description: "Additional interface options. A JSON-serialized object for an inline keyboard, custom reply keyboard, instructions to remove reply keyboard or to force a reply from the user."
        }
      },
      required: ["chat_id", "text"]
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
