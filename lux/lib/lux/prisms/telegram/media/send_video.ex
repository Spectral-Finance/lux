defmodule Lux.Prisms.Telegram.Media.SendVideo do
  @moduledoc """
  A prism for sending videos via the Telegram Bot API.

  This prism provides a simple interface to send videos to Telegram chats.
  It uses the Telegram Bot API to send videos either by URL, file ID, or local file.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /sendVideo
  - Supports required parameters (chat_id, video) and optional parameters like caption
  - Returns the sent message data on success
  - Preserves original Telegram API errors for better error handling by LLMs

  ## Examples

      # Send a video by URL
      iex> SendVideo.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   video: "https://example.com/video.mp4",
      ...>   caption: "Check out this video"
      ...> }, %{name: "Agent"})
      {:ok, %{sent: true, message_id: 42, chat_id: 123_456_789, video: "https://example.com/video.mp4"}}

      # Send a video with markdown formatting in caption
      iex> SendVideo.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   video: "https://example.com/video.mp4",
      ...>   caption: "*Bold* and _italic_ caption",
      ...>   parse_mode: "Markdown"
      ...> }, %{name: "Agent"})
      {:ok, %{sent: true, message_id: 42, chat_id: 123_456_789, video: "https://example.com/video.mp4"}}
  """

  use Lux.Prism,
    name: "Send Telegram Video",
    description: "Sends videos via the Telegram Bot API",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat or username of the target channel"
        },
        video: %{
          type: :string,
          description: "Video to send. Pass a file_id as String to send a video that exists on the Telegram servers, or pass an HTTP URL as a String for Telegram to get a video from the Internet"
        },
        duration: %{
          type: :integer,
          description: "Duration of sent video in seconds"
        },
        width: %{
          type: :integer,
          description: "Video width"
        },
        height: %{
          type: :integer,
          description: "Video height"
        },
        thumbnail: %{
          type: :string,
          description: "Thumbnail of the video file sent; can be ignored if thumbnail generation for the file is supported server-side"
        },
        caption: %{
          type: :string,
          description: "Video caption, 0-1024 characters after entities parsing"
        },
        parse_mode: %{
          type: :string,
          description: "Mode for parsing entities in the video caption",
          enum: ["Markdown", "MarkdownV2", "HTML"]
        },
        caption_entities: %{
          type: :array,
          description: "A JSON-serialized list of special entities that appear in the caption"
        },
        has_spoiler: %{
          type: :boolean,
          description: "Pass True if the video needs to be covered with a spoiler animation"
        },
        supports_streaming: %{
          type: :boolean,
          description: "Pass True if the uploaded video is suitable for streaming"
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
      required: ["chat_id", "video"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        sent: %{
          type: :boolean,
          description: "Whether the video was successfully sent"
        },
        message_id: %{
          type: :integer,
          description: "Identifier of the sent message"
        },
        chat_id: %{
          type: [:string, :integer],
          description: "Identifier of the target chat"
        },
        video: %{
          type: :string,
          description: "The video that was sent"
        },
        caption: %{
          type: :string,
          description: "Caption for the video, if provided"
        }
      },
      required: ["sent", "message_id"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to send a video to a Telegram chat.

  This implementation:
  - Makes a direct request to Telegram Bot API using the Client module
  - Returns success/failure responses without additional error transformation
  - Logs the operation for monitoring purposes
  """
  def handler(params, agent) do
    with {:ok, chat_id} <- validate_param(params, :chat_id),
         {:ok, video} <- validate_param(params, :video) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} sending video to chat #{chat_id}")

      # Build the request body
      request_body = Map.take(params, [:chat_id, :video, :duration, :width, :height,
                              :thumbnail, :caption, :parse_mode, :caption_entities,
                              :has_spoiler, :supports_streaming, :disable_notification,
                              :protect_content, :reply_to_message_id,
                              :allow_sending_without_reply, :reply_markup])

      # Prepare request options
      request_opts = %{json: request_body}

      case Client.request(:post, "/sendVideo", request_opts) do
        {:ok, %{"result" => result}} when is_map(result) ->
          Logger.info("Successfully sent video to chat #{chat_id}")

          # Extract caption for the response if it exists
          caption = Map.get(params, :caption)

          {:ok, %{
            sent: true,
            message_id: result["message_id"],
            chat_id: chat_id,
            video: video,
            caption: caption
          }}

        {:error, {status, %{"description" => description}}} ->
          {:error, "Failed to send video: #{description} (HTTP #{status})"}

        {:error, {status, description}} when is_binary(description) ->
          {:error, "Failed to send video: #{description} (HTTP #{status})"}

        {:error, error} ->
          {:error, "Failed to send video: #{inspect(error)}"}
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
