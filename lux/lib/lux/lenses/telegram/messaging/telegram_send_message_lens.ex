defmodule Lux.Lenses.Telegram.SendMessage do
  @moduledoc """
  Lens for sending messages via the Telegram Bot API.

  This lens provides functionality to send text messages to Telegram chats.

  ## Example

  ```elixir
  alias Lux.Lenses.Telegram.SendMessage

  # Send a simple message
  SendMessage.focus(%{
    chat_id: 123456789,
    text: "Hello from Lux!"
  })

  # Send a message with markdown formatting
  SendMessage.focus(%{
    chat_id: 123456789,
    text: "*Bold* and _italic_ text",
    parse_mode: "Markdown"
  })
  ```
  """

  use Lux.Lens,
    name: "Telegram Send Message API",
    description: "Sends text messages via the Telegram Bot API",
    url: "https://api.telegram.org/bot",
    method: :post,
    headers: [{"content-type", "application/json"}],
    auth: %{
      type: :custom,
      auth_function: &__MODULE__.add_bot_token/1
    },
    schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat or username of the target channel"
        },
        text: %{
          type: :string,
          description: "Text of the message to be sent"
        },
        parse_mode: %{
          type: :string,
          description: "Mode for parsing entities in the message text",
          enum: ["Markdown", "MarkdownV2", "HTML"]
        },
        disable_web_page_preview: %{
          type: :boolean,
          description: "Disables link previews for links in this message"
        },
        disable_notification: %{
          type: :boolean,
          description: "Sends the message silently. Users will receive a notification with no sound."
        },
        protect_content: %{
          type: :boolean,
          description: "Protects the contents of the sent message from forwarding and saving"
        },
        reply_to_message_id: %{
          type: :integer,
          description: "If the message is a reply, ID of the original message"
        },
        allow_sending_without_reply: %{
          type: :boolean,
          description: "Pass True if the message should be sent even if the specified replied-to message is not found"
        }
      },
      required: ["chat_id", "text"]
    }

  @doc """
  Adds the bot token to the URL and appends the sendMessage method.
  """
  def add_bot_token(lens) do
    token = Lux.Config.telegram_bot_token()
    url = lens.url <> token <> "/sendMessage"
    %{lens | url: url}
  end

  @doc """
  Transforms the API response into a more usable format.

  ## Examples

      iex> after_focus(%{"ok" => true, "result" => %{"message_id" => 123}})
      {:ok, %{message_id: 123, ...}}

      iex> after_focus(%{"ok" => false, "description" => "Bad Request"})
      {:error, %{"description" => "Bad Request"}}
  """
  @impl true
  def after_focus(%{"ok" => true, "result" => result}) do
    # Transform the result to a more Elixir-friendly format with atom keys
    transformed_result = %{
      message_id: result["message_id"],
      from: result["from"],
      chat: result["chat"],
      date: result["date"],
      text: result["text"]
    }

    {:ok, transformed_result}
  end

  @impl true
  def after_focus(%{"ok" => false, "description" => description}) do
    # Return the error response as is to match test expectations
    {:error, %{"ok" => false, "description" => description}}
  end

  @impl true
  def after_focus(response) do
    {:error, response}
  end
end
