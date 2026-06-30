defmodule Lux.Prisms.Telegram.Media.SendAudio do
  @moduledoc """
  A prism for sending audio files via the Telegram Bot API.

  This prism provides a simple interface to send audio files to Telegram chats.
  It uses the Telegram Bot API to send audio files either by URL, file ID, or local file.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /sendAudio
  - Supports required parameters (chat_id, audio) and optional parameters like caption
  - Returns the sent message data on success
  - Preserves original Telegram API errors for better error handling by LLMs

  ## Examples

      # Send an audio file by URL
      iex> SendAudio.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   audio: "https://example.com/audio.mp3",
      ...>   caption: "Check out this song"
      ...> }, %{name: "Agent"})
      {:ok, %{sent: true, message_id: 42, chat_id: 123_456_789, audio: "https://example.com/audio.mp3"}}

      # Send an audio file with markdown formatting in caption
      iex> SendAudio.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   audio: "https://example.com/audio.mp3",
      ...>   caption: "*Bold* and _italic_ caption",
      ...>   parse_mode: "Markdown"
      ...> }, %{name: "Agent"})
      {:ok, %{sent: true, message_id: 42, chat_id: 123_456_789, audio: "https://example.com/audio.mp3"}}
  """

  use Lux.Prism,
    name: "Send Telegram Audio",
    description: "Sends audio files via the Telegram Bot API",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat or username of the target channel"
        },
        audio: %{
          type: :string,
          description: "Audio file to send. Pass a file_id as String to send an audio file that exists on the Telegram servers, or pass an HTTP URL as a String for Telegram to get an audio file from the Internet"
        },
        duration: %{
          type: :integer,
          description: "Duration of the audio in seconds"
        },
        performer: %{
          type: :string,
          description: "Performer of the audio"
        },
        title: %{
          type: :string,
          description: "Title of the audio"
        },
        thumbnail: %{
          type: :string,
          description: "Thumbnail of the file sent; can be ignored if thumbnail generation for the file is supported server-side"
        },
        caption: %{
          type: :string,
          description: "Audio caption, 0-1024 characters after entities parsing"
        },
        parse_mode: %{
          type: :string,
          description: "Mode for parsing entities in the audio caption",
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
      required: ["chat_id", "audio"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        sent: %{
          type: :boolean,
          description: "Whether the audio was successfully sent"
        },
        message_id: %{
          type: :integer,
          description: "Identifier of the sent message"
        },
        chat_id: %{
          type: [:string, :integer],
          description: "Identifier of the target chat"
        },
        audio: %{
          type: :string,
          description: "The audio file that was sent"
        },
        caption: %{
          type: :string,
          description: "Caption for the audio, if provided"
        }
      },
      required: ["sent", "message_id"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to send an audio file to a Telegram chat.

  This implementation:
  - Makes a direct request to Telegram Bot API using the Client module
  - Returns success/failure responses without additional error transformation
  - Logs the operation for monitoring purposes
  """
  def handler(params, agent) do
    with {:ok, chat_id} <- validate_param(params, :chat_id),
         {:ok, audio} <- validate_param(params, :audio) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} sending audio to chat #{chat_id}")

      # Build the request body
      request_body = Map.take(params, [:chat_id, :audio, :duration, :performer,
                              :title, :thumbnail, :caption, :parse_mode,
                              :caption_entities, :disable_notification,
                              :protect_content, :reply_to_message_id,
                              :allow_sending_without_reply, :reply_markup])

      # Prepare request options
      request_opts = %{json: request_body}

      case Client.request(:post, "/sendAudio", request_opts) do
        {:ok, %{"result" => result}} when is_map(result) ->
          Logger.info("Successfully sent audio to chat #{chat_id}")

          # Extract caption for the response if it exists
          caption = Map.get(params, :caption)

          {:ok, %{
            sent: true,
            message_id: result["message_id"],
            chat_id: chat_id,
            audio: audio,
            caption: caption
          }}

        {:error, {status, %{"description" => description}}} ->
          {:error, "Failed to send audio: #{description} (HTTP #{status})"}

        {:error, {status, description}} when is_binary(description) ->
          {:error, "Failed to send audio: #{description} (HTTP #{status})"}

        {:error, error} ->
          {:error, "Failed to send audio: #{inspect(error)}"}
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
