defmodule Lux.Lenses.Telegram.Media.SendPhoto do
  @moduledoc """
  A lens for sending photos via the Telegram Bot API.

  This lens sends a photo to a chat. The photo can be specified as:
  - A file_id of an existing photo on Telegram servers
  - An HTTP URL for Telegram to download the photo
  - (File upload via multipart/form-data is not supported through lenses)

  ## Examples

      # Send by URL
      iex> SendPhoto.focus(%{
      ...>   chat_id: 123_456_789,
      ...>   photo: "https://example.com/photo.jpg",
      ...>   caption: "A beautiful photo"
      ...> })
      {:ok, %{
        message_id: 456,
        chat_id: 123_456_789,
        photo: [%{file_id: "abc123", width: 800, height: 600}]
      }}

      # Send by file_id
      iex> SendPhoto.focus(%{
      ...>   chat_id: 123_456_789,
      ...>   photo: "AgACAgIAAxkBAAI..."
      ...> })
      {:ok, %{
        message_id: 457,
        chat_id: 123_456_789,
        photo: [%{file_id: "abc123", width: 800, height: 600}]
      }}
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Send Telegram Photo",
    description: "Sends a photo to a chat via the Telegram Bot API",
    url: Telegram.api_url("sendPhoto"),
    method: :post,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat or username of the target channel"
        },
        photo: %{
          type: :string,
          description: "Photo to send. Pass a file_id to send a file on Telegram servers, or an HTTP URL for Telegram to get a photo from the Internet."
        },
        caption: %{
          type: :string,
          description: "Photo caption, 0-1024 characters"
        },
        parse_mode: %{
          type: :string,
          description: "Mode for parsing entities in the caption",
          enum: ["Markdown", "MarkdownV2", "HTML"]
        },
        disable_notification: %{
          type: :boolean,
          description: "Sends the message silently"
        },
        protect_content: %{
          type: :boolean,
          description: "Protects the contents of the sent message from forwarding and saving"
        },
        reply_to_message_id: %{
          type: :integer,
          description: "If the message is a reply, ID of the original message"
        },
        has_spoiler: %{
          type: :boolean,
          description: "Pass True if the photo should be sent with a spoiler animation"
        }
      },
      required: ["chat_id", "photo"]
    }

  @doc """
  Transforms the Telegram API response into a clean format.
  """
  @impl true
  def after_focus(%{"ok" => true, "result" => result}) do
    photos = Enum.map(result["photo"] || [], fn photo ->
      %{
        file_id: photo["file_id"],
        file_unique_id: photo["file_unique_id"],
        width: photo["width"],
        height: photo["height"],
        file_size: photo["file_size"]
      }
    end)

    {:ok, %{
      message_id: result["message_id"],
      chat_id: result["chat"]["id"],
      photo: photos,
      caption: result["caption"],
      date: result["date"]
    }}
  end

  def after_focus(%{"ok" => false, "error_code" => 429, "parameters" => %{"retry_after" => retry_after}} = error) do
    {:error, %{
      reason: :rate_limited,
      retry_after: retry_after,
      description: error["description"]
    }}
  end

  def after_focus(%{"ok" => false, "description" => description, "error_code" => code}) do
    {:error, %{reason: :api_error, error_code: code, description: description}}
  end

  def after_focus(%{"description" => description}) do
    {:error, %{reason: :api_error, description: description}}
  end
end
