defmodule Lux.Lenses.Telegram.CopyMessage do
  @moduledoc """
  Lens for copying messages via the Telegram Bot API.

  This lens provides functionality to copy messages from one chat to another.
  Unlike forwarding, copied messages don't have a link to the original message.

  ## Example

  ```elixir
  alias Lux.Lenses.Telegram.CopyMessage

  # Copy a message
  CopyMessage.focus(%{
    chat_id: 123456789,
    from_chat_id: 987654321,
    message_id: 42
  })

  # Copy a message silently (without notification)
  CopyMessage.focus(%{
    chat_id: 123456789,
    from_chat_id: 987654321,
    message_id: 42,
    disable_notification: true
  })

  # Copy a message with a new caption
  CopyMessage.focus(%{
    chat_id: 123456789,
    from_chat_id: 987654321,
    message_id: 42,
    caption: "New caption for the copied message",
    parse_mode: "Markdown"
  })
  ```
  """

  use Lux.Lens,
    name: "Telegram Copy Message API",
    description: "Copies messages via the Telegram Bot API",
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
        from_chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the chat where the original message was sent"
        },
        message_id: %{
          type: :integer,
          description: "Message identifier in the chat specified in from_chat_id"
        },
        caption: %{
          type: :string,
          description: "New caption for media, 0-1024 characters after entities parsing"
        },
        parse_mode: %{
          type: :string,
          description: "Mode for parsing entities in the new caption",
          enum: ["Markdown", "MarkdownV2", "HTML"]
        },
        disable_notification: %{
          type: :boolean,
          description: "Sends the message silently. Users will receive a notification with no sound."
        },
        protect_content: %{
          type: :boolean,
          description: "Protects the contents of the copied message from forwarding and saving"
        }
      },
      required: ["chat_id", "from_chat_id", "message_id"]
    }

  @doc """
  Adds the bot token to the URL and appends the copyMessage method.
  """
  def add_bot_token(lens) do
    token = Lux.Config.telegram_bot_token()
    url = lens.url <> token <> "/copyMessage"
    %{lens | url: url}
  end

  @doc """
  Transforms the API response into a more usable format.

  ## Examples

      iex> after_focus(%{"ok" => true, "result" => %{"message_id" => 123}})
      {:ok, %{message_id: 123}}

      iex> after_focus(%{"ok" => false, "description" => "Bad Request"})
      {:error, %{"ok" => false, "description" => "Bad Request"}}
  """
  @impl true
  def after_focus(%{"ok" => true, "result" => result}) do
    # Transform the result to a more Elixir-friendly format with atom keys
    # For copyMessage, the result is just a message_id
    transformed_result = %{
      message_id: result["message_id"]
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
