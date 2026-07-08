defmodule Lux.Prisms.Telegram.Media.SendDocument do
  @moduledoc """
  A prism for sending documents via the Telegram Bot API.

  This prism provides a simple interface to send documents to Telegram chats.
  It uses the Telegram Bot API to send documents either by URL, file ID, or local file.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /sendDocument
  - Supports required parameters (chat_id, document) and optional parameters like caption
  - Returns the sent message data on success
  - Preserves original Telegram API errors for better error handling by LLMs

  ## Examples

      # Send a document by URL
      iex> SendDocument.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   document: "https://example.com/document.pdf",
      ...>   caption: "Important document"
      ...> }, %{name: "Agent"})
      {:ok, %{sent: true, message_id: 42, chat_id: 123_456_789, document: "https://example.com/document.pdf"}}

      # Send a document with markdown formatting in caption
      iex> SendDocument.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   document: "https://example.com/document.pdf",
      ...>   caption: "*Bold* and _italic_ caption",
      ...>   parse_mode: "Markdown"
      ...> }, %{name: "Agent"})
      {:ok, %{sent: true, message_id: 42, chat_id: 123_456_789, document: "https://example.com/document.pdf"}}
  """

  use Lux.Prism,
    name: "Send Telegram Document",
    description: "Sends documents via the Telegram Bot API",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat or username of the target channel"
        },
        document: %{
          type: :string,
          description: "Document to send. Pass a file_id as String to send a document that exists on the Telegram servers, or pass an HTTP URL as a String for Telegram to get a document from the Internet"
        },
        caption: %{
          type: :string,
          description: "Document caption, 0-1024 characters after entities parsing"
        },
        parse_mode: %{
          type: :string,
          description: "Mode for parsing entities in the document caption",
          enum: ["Markdown", "MarkdownV2", "HTML"]
        },
        caption_entities: %{
          type: :array,
          description: "A JSON-serialized list of special entities that appear in the caption"
        },
        disable_content_type_detection: %{
          type: :boolean,
          description: "Disables automatic server-side content type detection for files uploaded using multipart/form-data"
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
      required: ["chat_id", "document"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        sent: %{
          type: :boolean,
          description: "Whether the document was successfully sent"
        },
        message_id: %{
          type: :integer,
          description: "Identifier of the sent message"
        },
        chat_id: %{
          type: [:string, :integer],
          description: "Identifier of the target chat"
        },
        document: %{
          type: :string,
          description: "The document that was sent"
        },
        caption: %{
          type: :string,
          description: "Caption for the document, if provided"
        }
      },
      required: ["sent", "message_id"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to send a document to a Telegram chat.

  This implementation:
  - Makes a direct request to Telegram Bot API using the Client module
  - Returns success/failure responses without additional error transformation
  - Logs the operation for monitoring purposes
  """
  def handler(params, agent) do
    with {:ok, chat_id} <- validate_param(params, :chat_id),
         {:ok, document} <- validate_param(params, :document) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} sending document to chat #{chat_id}")

      # Build the request body
      request_body = Map.take(params, [:chat_id, :document, :caption, :parse_mode,
                              :caption_entities, :disable_content_type_detection,
                              :disable_notification, :protect_content,
                              :reply_to_message_id, :allow_sending_without_reply,
                              :reply_markup])

      # Prepare request options
      request_opts = %{json: request_body}

      case Client.request(:post, "/sendDocument", request_opts) do
        {:ok, %{"result" => result}} when is_map(result) ->
          Logger.info("Successfully sent document to chat #{chat_id}")

          # Extract caption for the response if it exists
          caption = Map.get(params, :caption)

          {:ok, %{
            sent: true,
            message_id: result["message_id"],
            chat_id: chat_id,
            document: document,
            caption: caption
          }}

        {:error, {status, %{"description" => description}}} ->
          {:error, "Failed to send document: #{description} (HTTP #{status})"}

        {:error, {status, description}} when is_binary(description) ->
          {:error, "Failed to send document: #{description} (HTTP #{status})"}

        {:error, error} ->
          {:error, "Failed to send document: #{inspect(error)}"}
      end
    end
  end

  defp validate_param(params, key, _type \\ :any) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      {:ok, value} when is_integer(value) -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
