defmodule Lux.Prisms.Telegram.Media.SendVideoNote do
  @moduledoc """
  A prism for sending video notes via the Telegram Bot API.

  This prism provides a simple interface to send video notes (round videos) to Telegram chats.
  It uses the Telegram Bot API to send video notes either by URL or file ID.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /sendVideoNote
  - Supports required parameters (chat_id, video_note) and optional parameters like duration
  - Returns the sent message data on success
  - Preserves original Telegram API errors for better error handling by LLMs

  ## Examples

      # Send a video note by URL
      iex> SendVideoNote.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   video_note: "https://example.com/video_note.mp4"
      ...> }, %{name: "Agent"})
      {:ok, %{sent: true, message_id: 42, chat_id: 123_456_789, video_note: "https://example.com/video_note.mp4"}}

      # Send a video note with duration and size
      iex> SendVideoNote.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   video_note: "https://example.com/video_note.mp4",
      ...>   duration: 30,
      ...>   length: 360
      ...> }, %{name: "Agent"})
      {:ok, %{sent: true, message_id: 42, chat_id: 123_456_789, video_note: "https://example.com/video_note.mp4"}}
  """

  use Lux.Prism,
    name: "Send Telegram Video Note",
    description: "Sends video notes (round videos) via the Telegram Bot API",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat or username of the target channel"
        },
        video_note: %{
          type: :string,
          description: "Video note to send. Pass a file_id as String to send a video note that exists on the Telegram servers, or pass an HTTP URL as a String for Telegram to get a video note from the Internet"
        },
        duration: %{
          type: :integer,
          description: "Duration of sent video note in seconds"
        },
        length: %{
          type: :integer,
          description: "Video width and height, i.e. diameter of the video message"
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
      required: ["chat_id", "video_note"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        sent: %{
          type: :boolean,
          description: "Whether the video note was successfully sent"
        },
        message_id: %{
          type: :integer,
          description: "Identifier of the sent message"
        },
        chat_id: %{
          type: [:string, :integer],
          description: "Identifier of the target chat"
        },
        video_note: %{
          type: :string,
          description: "The video note that was sent"
        }
      },
      required: ["sent", "message_id"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to send a video note to a Telegram chat.

  This implementation:
  - Makes a direct request to Telegram Bot API using the Client module
  - Returns success/failure responses without additional error transformation
  - Logs the operation for monitoring purposes
  """
  def handler(params, agent) do
    with {:ok, chat_id} <- validate_param(params, :chat_id),
         {:ok, video_note} <- validate_param(params, :video_note) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} sending video note to chat #{chat_id}")

      # Build the request body
      request_body = Map.take(params, [:chat_id, :video_note, :duration, :length,
                              :disable_notification, :protect_content,
                              :reply_to_message_id, :allow_sending_without_reply,
                              :reply_markup])

      # Prepare request options
      request_opts = %{json: request_body}

      case Client.request(:post, "/sendVideoNote", request_opts) do
        {:ok, %{"result" => result}} when is_map(result) ->
          Logger.info("Successfully sent video note to chat #{chat_id}")

          {:ok, %{
            sent: true,
            message_id: result["message_id"],
            chat_id: chat_id,
            video_note: video_note
          }}

        {:error, {status, %{"description" => description}}} ->
          {:error, "Failed to send video note: #{description} (HTTP #{status})"}

        {:error, {status, description}} when is_binary(description) ->
          {:error, "Failed to send video note: #{description} (HTTP #{status})"}

        {:error, error} ->
          {:error, "Failed to send video note: #{inspect(error)}"}
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
