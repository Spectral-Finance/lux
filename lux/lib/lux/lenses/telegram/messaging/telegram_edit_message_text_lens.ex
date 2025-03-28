defmodule Lux.Lenses.Telegram.EditMessageText do
  @moduledoc """
  Lens for editing message text via the Telegram Bot API.

  This lens provides functionality to edit text messages in Telegram chats.

  ## Example

  ```elixir
  alias Lux.Lenses.Telegram.EditMessageText

  # Edit a message text
  EditMessageText.focus(%{
    chat_id: 123456789,
    message_id: 42,
    text: "Updated message text"
  })

  # Edit a message with markdown formatting
  EditMessageText.focus(%{
    chat_id: 123456789,
    message_id: 42,
    text: "*Bold* and _italic_ text",
    parse_mode: "Markdown"
  })

  # Edit an inline message text
  EditMessageText.focus(%{
    inline_message_id: "123456789",
    text: "Updated inline message text"
  })
  ```
  """

  use Lux.Lens,
    name: "Telegram Edit Message Text API",
    description: "Edits text messages via the Telegram Bot API",
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
          description: "Required if inline_message_id is not specified. Unique identifier for the target chat or username of the target channel"
        },
        message_id: %{
          type: :integer,
          description: "Required if inline_message_id is not specified. Identifier of the message to edit"
        },
        inline_message_id: %{
          type: :string,
          description: "Required if chat_id and message_id are not specified. Identifier of the inline message"
        },
        text: %{
          type: :string,
          description: "New text of the message, 1-4096 characters after entities parsing"
        },
        parse_mode: %{
          type: :string,
          description: "Mode for parsing entities in the message text",
          enum: ["Markdown", "MarkdownV2", "HTML"]
        },
        entities: %{
          type: :array,
          description: "A JSON-serialized list of special entities that appear in message text"
        },
        disable_web_page_preview: %{
          type: :boolean,
          description: "Disables link previews for links in this message"
        },
        reply_markup: %{
          type: :object,
          description: "A JSON-serialized object for an inline keyboard"
        }
      },
      required: ["text"]
    }

  @doc """
  Adds the bot token to the URL and appends the editMessageText method.
  """
  def add_bot_token(lens) do
    token = Lux.Config.telegram_bot_token()
    url = lens.url <> token <> "/editMessageText"
    %{lens | url: url}
  end

  @doc """
  Transforms the API response into a more usable format.

  ## Examples

      iex> after_focus(%{"ok" => true, "result" => %{"message_id" => 123}})
      {:ok, %{message_id: 123, ...}}

      iex> after_focus(%{"ok" => false, "description" => "Bad Request"})
      {:error, "Bad Request"}
  """
  @impl true
  def after_focus(%{"ok" => true, "result" => result}) when is_map(result) do
    # Transform the result to a more Elixir-friendly format with atom keys
    transformed_result = %{
      message_id: result["message_id"],
      from: result["from"],
      chat: result["chat"],
      date: result["date"],
      edit_date: result["edit_date"],
      text: result["text"]
    }

    {:ok, transformed_result}
  end

  @impl true
  def after_focus(%{"ok" => true, "result" => true}) do
    # For inline message edits, the API returns just "result": true
    {:ok, true}
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
