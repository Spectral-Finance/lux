defmodule Lux.Lenses.Telegram.DeleteMessage do
  @moduledoc """
  Lens for deleting messages via the Telegram Bot API.

  This lens provides functionality to delete messages from Telegram chats.

  ## Example

  ```elixir
  alias Lux.Lenses.Telegram.DeleteMessage

  # Delete a message
  DeleteMessage.focus(%{
    chat_id: 123456789,
    message_id: 42
  })
  ```
  """

  use Lux.Lens,
    name: "Telegram Delete Message API",
    description: "Deletes messages via the Telegram Bot API",
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
        message_id: %{
          type: :integer,
          description: "Identifier of the message to delete"
        }
      },
      required: ["chat_id", "message_id"]
    }

  @doc """
  Adds the bot token to the URL and appends the deleteMessage method.
  """
  def add_bot_token(lens) do
    token = Lux.Config.telegram_bot_token()
    url = lens.url <> token <> "/deleteMessage"
    %{lens | url: url}
  end

  @doc """
  Transforms the API response into a more usable format.

  ## Examples

      iex> after_focus(%{"ok" => true, "result" => true})
      {:ok, true}

      iex> after_focus(%{"ok" => false, "description" => "Bad Request"})
      {:error, %{"ok" => false, "description" => "Bad Request"}}
  """
  @impl true
  def after_focus(%{"ok" => true, "result" => true}) do
    {:ok, true}
  end

  @impl true
  def after_focus(%{"ok" => false, "description" => description}) do
    # Return full error response to match test expectations
    {:error, %{"ok" => false, "description" => description}}
  end

  @impl true
  def after_focus(response) do
    {:error, response}
  end
end
