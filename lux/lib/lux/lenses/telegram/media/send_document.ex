defmodule Lux.Lenses.Telegram.Media.SendDocument do
  @moduledoc """
  A lens for sending documents via the Telegram Bot API.

  This lens sends general files (documents) to a chat. The document can be specified as:
  - A file_id of an existing document on Telegram servers
  - An HTTP URL for Telegram to download the document
  - (File upload via multipart/form-data is not supported through lenses)

  ## File Size Limits

  Bots can send files of any type up to 50 MB in size via URL.

  ## Examples

      # Send a document by URL
      iex> SendDocument.focus(%{
      ...>   chat_id: 123_456_789,
      ...>   document: "https://example.com/report.pdf",
      ...>   caption: "Monthly report"
      ...> })
      {:ok, %{
        message_id: 456,
        chat_id: 123_456_789,
        document: %{file_id: "BQACAgI...", file_name: "report.pdf"}
      }}

      # Send a document by file_id
      iex> SendDocument.focus(%{
      ...>   chat_id: 123_456_789,
      ...>   document: "BQACAgIAAxkBAAI..."
      ...> })
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Send Telegram Document",
    description: "Sends a document (general file) to a chat via the Telegram Bot API",
    url: Telegram.api_url("sendDocument"),
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
        document: %{
          type: :string,
          description: "File to send. Pass a file_id to send a file on Telegram servers, or an HTTP URL for Telegram to get a file from the Internet."
        },
        thumbnail: %{
          type: :string,
          description: "Thumbnail of the file sent; can be a file_id or HTTP URL. The thumbnail should be in JPEG format and less than 200 kB in size."
        },
        caption: %{
          type: :string,
          description: "Document caption, 0-1024 characters"
        },
        parse_mode: %{
          type: :string,
          description: "Mode for parsing entities in the caption",
          enum: ["Markdown", "MarkdownV2", "HTML"]
        },
        disable_content_type_detection: %{
          type: :boolean,
          description: "Disables automatic server-side content type detection for files uploaded using multipart/form-data"
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
        }
      },
      required: ["chat_id", "document"]
    }

  @doc """
  Transforms the Telegram API response into a clean format.
  """
  @impl true
  def after_focus(%{"ok" => true, "result" => result}) do
    doc = result["document"] || %{}

    {:ok, %{
      message_id: result["message_id"],
      chat_id: result["chat"]["id"],
      document: %{
        file_id: doc["file_id"],
        file_unique_id: doc["file_unique_id"],
        file_name: doc["file_name"],
        mime_type: doc["mime_type"],
        file_size: doc["file_size"]
      },
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
