defmodule Lux.Lenses.Telegram.ForwardMessage do
  @moduledoc """
  Lens for forwarding messages via the Telegram Bot API.

  This lens provides functionality to forward messages from one chat to another.

  ## Example

  ```elixir
  alias Lux.Lenses.Telegram.ForwardMessage

  # Forward a message
  ForwardMessage.focus(%{
    chat_id: 123456789,
    from_chat_id: 987654321,
    message_id: 42
  })

  # Forward a message silently (without notification)
  ForwardMessage.focus(%{
    chat_id: 123456789,
    from_chat_id: 987654321,
    message_id: 42,
    disable_notification: true
  })
  ```
  """

  use Lux.Lens,
    name: "Telegram Forward Message API",
    description: "Forwards messages via the Telegram Bot API",
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
        disable_notification: %{
          type: :boolean,
          description: "Sends the message silently. Users will receive a notification with no sound."
        },
        protect_content: %{
          type: :boolean,
          description: "Protects the contents of the forwarded message from forwarding and saving"
        }
      },
      required: ["chat_id", "from_chat_id", "message_id"]
    }

  @doc """
  Adds the bot token to the URL and appends the forwardMessage method.
  """
  def add_bot_token(lens) do
    token = Lux.Config.telegram_bot_token()
    url = lens.url <> token <> "/forwardMessage"
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
      forward_from: result["forward_from"],
      forward_from_chat: result["forward_from_chat"],
      forward_date: result["forward_date"],
      text: result["text"],
      caption: result["caption"]
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
