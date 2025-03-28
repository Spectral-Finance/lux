defmodule Lux.Lenses.Telegram.EditMessageCaption do
  @moduledoc """
  Lens for editing message captions via the Telegram Bot API.

  This lens provides functionality to edit captions of media messages in Telegram chats.

  ## Example

  ```elixir
  alias Lux.Lenses.Telegram.EditMessageCaption

  # Edit a message caption
  EditMessageCaption.focus(%{
    chat_id: 123456789,
    message_id: 42,
    caption: "Updated caption"
  })

  # Edit a message with markdown formatting
  EditMessageCaption.focus(%{
    chat_id: 123456789,
    message_id: 42,
    caption: "*Bold* and _italic_ caption",
    parse_mode: "Markdown"
  })

  # Edit an inline message caption
  EditMessageCaption.focus(%{
    inline_message_id: "123456789",
    caption: "Updated inline message caption"
  })
  ```
  """

  use Lux.Lens,
    name: "Telegram Edit Message Caption API",
    description: "Edits message captions via the Telegram Bot API",
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
        caption: %{
          type: :string,
          description: "New caption of the message, 0-1024 characters after entities parsing"
        },
        parse_mode: %{
          type: :string,
          description: "Mode for parsing entities in the message caption",
          enum: ["Markdown", "MarkdownV2", "HTML"]
        },
        caption_entities: %{
          type: :array,
          description: "A JSON-serialized list of special entities that appear in the caption"
        },
        reply_markup: %{
          type: :object,
          description: "A JSON-serialized object for an inline keyboard"
        }
      },
      required: ["caption"]
    }

  @doc """
  Adds the bot token to the URL and appends the editMessageCaption method.
  """
  def add_bot_token(lens) do
    token = Lux.Config.telegram_bot_token()
    url = lens.url <> token <> "/editMessageCaption"
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
      caption: result["caption"]
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
