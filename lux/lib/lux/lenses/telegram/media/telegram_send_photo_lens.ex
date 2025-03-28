defmodule Lux.Lenses.Telegram.SendPhoto do
  @moduledoc """
  Lens for sending photos via the Telegram Bot API.

  This lens provides functionality to send photos to Telegram chats.

  ## Example

  ```elixir
  alias Lux.Lenses.Telegram.SendPhoto

  # Send a photo by URL
  SendPhoto.focus(%{
    chat_id: 123456789,
    photo: "https://example.com/photo.jpg",
    caption: "A beautiful photo"
  })

  # Send a photo with markdown formatting in caption
  SendPhoto.focus(%{
    chat_id: 123456789,
    photo: "https://example.com/photo.jpg",
    caption: "*Bold* and _italic_ caption",
    parse_mode: "Markdown"
  })
  ```
  """

  use Lux.Lens,
    name: "Telegram Send Photo API",
    description: "Sends photos via the Telegram Bot API",
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
        photo: %{
          type: :string,
          description: "Photo to send. Pass a file_id as String to send a photo that exists on the Telegram servers, or pass an HTTP URL as a String for Telegram to get a photo from the Internet"
        },
        caption: %{
          type: :string,
          description: "Photo caption, 0-1024 characters after entities parsing"
        },
        parse_mode: %{
          type: :string,
          description: "Mode for parsing entities in the photo caption",
          enum: ["Markdown", "MarkdownV2", "HTML"]
        },
        caption_entities: %{
          type: :array,
          description: "A JSON-serialized list of special entities that appear in the caption"
        },
        disable_notification: %{
          type: :boolean,
          description: "Sends the message silently. Users will receive a notification with no sound"
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
        },
        reply_markup: %{
          type: :object,
          description: "Additional interface options. A JSON-serialized object for an inline keyboard, custom reply keyboard, instructions to remove reply keyboard or to force a reply from the user"
        }
      },
      required: ["chat_id", "photo"]
    }

  @doc """
  Adds the bot token to the URL and appends the sendPhoto method.
  """
  def add_bot_token(lens) do
    token = Lux.Config.telegram_bot_token()
    url = lens.url <> token <> "/sendPhoto"
    %{lens | url: url}
  end

  @doc """
  Transforms the API response into a more usable format.

  ## Examples

      iex> after_focus(%{"ok" => true, "result" => %{"message_id" => 123}})
      {:ok, %{message_id: 123, ...}}

      iex> after_focus(%{"ok" => false, "description" => "Bad Request"})
      {:error, %{"ok" => false, "description" => "Bad Request"}}
  """
  @impl true
  def after_focus(%{"ok" => true, "result" => result}) when is_map(result) do
    # Transform the result to a more Elixir-friendly format with atom keys
    transformed_result = %{
      message_id: result["message_id"],
      from: result["from"],
      chat: result["chat"],
      date: result["date"],
      photo: result["photo"],
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
