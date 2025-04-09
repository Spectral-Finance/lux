defmodule Lux.Prisms.Telegram.Media.SendMediaGroup do
  @moduledoc """
  A prism for sending media groups (albums) via the Telegram Bot API.

  This prism provides a simple interface to send groups of photos, videos, documents and audio files
  as an album to Telegram chats. It uses the Telegram Bot API's sendMediaGroup endpoint.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /sendMediaGroup
  - Supports required parameters (chat_id, media) and optional parameters
  - Returns the sent messages data on success
  - Preserves original Telegram API errors for better error handling by LLMs

  ## Examples

      # Send a media group with photos
      iex> SendMediaGroup.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   media: [
      ...>     %{
      ...>       type: "photo",
      ...>       media: "https://example.com/photo1.jpg",
      ...>       caption: "First photo"
      ...>     },
      ...>     %{
      ...>       type: "photo",
      ...>       media: "https://example.com/photo2.jpg",
      ...>       caption: "Second photo"
      ...>     }
      ...>   ]
      ...> }, %{name: "Agent"})
      {:ok, %{sent: true, message_ids: [42, 43], chat_id: 123_456_789}}
  """

  use Lux.Prism,
    name: "Send Telegram Media Group",
    description: "Sends a group of photos, videos, documents or audio files as an album via the Telegram Bot API",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat or username of the target channel"
        },
        media: %{
          type: :array,
          description: "A JSON-serialized array describing photos, videos, documents or audio files to be sent (2-10 items)",
          items: %{
            type: :object,
            properties: %{
              type: %{
                type: :string,
                description: "Type of media, must be one of 'photo', 'video', 'audio', or 'document'"
              },
              media: %{
                type: :string,
                description: "File to send. Pass a file_id to send a file that exists on the Telegram servers, pass an HTTP URL for Telegram to get a file from the Internet"
              },
              caption: %{
                type: :string,
                description: "Caption of the media to be sent, 0-1024 characters after entities parsing"
              },
              parse_mode: %{
                type: :string,
                description: "Mode for parsing entities in the caption. See formatting options for more details"
              },
              caption_entities: %{
                type: :array,
                description: "List of special entities that appear in the caption",
                items: %{
                  type: :object
                }
              }
            },
            required: ["type", "media"]
          }
        },
        disable_notification: %{
          type: :boolean,
          description: "Sends messages silently. Users will receive a notification with no sound"
        },
        protect_content: %{
          type: :boolean,
          description: "Protects the contents of sent messages from forwarding and saving"
        },
        reply_to_message_id: %{
          type: :integer,
          description: "If the messages are a reply, ID of the original message"
        },
        allow_sending_without_reply: %{
          type: :boolean,
          description: "Pass True if the message should be sent even if the specified replied-to message is not found"
        },
        plug: %{
          type: :object,
          description: "Additional plug parameters"
        }
      },
      required: ["chat_id", "media"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        sent: %{
          type: :boolean,
          description: "Whether the media group was successfully sent"
        },
        message_ids: %{
          type: :array,
          description: "Identifiers of the sent messages",
          items: %{
            type: :integer
          }
        },
        chat_id: %{
          type: [:string, :integer],
          description: "Identifier of the target chat"
        }
      },
      required: ["sent", "message_ids", "chat_id"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to send a media group to a Telegram chat.

  This implementation:
  - Makes a direct request to Telegram Bot API using the Client module
  - Returns success/failure responses without additional error transformation
  - Logs the operation for monitoring purposes
  """
  def handler(params, agent) do
    with {:ok, chat_id} <- validate_param(params, :chat_id),
         {:ok, media} <- validate_media(params) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} sending media group to chat #{chat_id}")

      # Build the request body with validated parameters
      request_body = params
      |> Map.take([:chat_id, :media, :disable_notification, :protect_content,
                   :reply_to_message_id, :allow_sending_without_reply])
      |> Map.merge(%{
        chat_id: chat_id,
        media: media
      })

      # Prepare request options
      request_opts = %{json: request_body}
      |> Map.merge(Map.take(params, [:plug]))

      case Client.request(:post, "/sendMediaGroup", request_opts) do
        {:ok, %{"result" => result}} when is_list(result) ->
          Logger.info("Successfully sent media group to chat #{chat_id}")

          {:ok, %{
            sent: true,
            message_ids: Enum.map(result, & &1["message_id"]),
            chat_id: chat_id
          }}

        {:error, {status, %{"description" => description}}} ->
          {:error, "Failed to send media group: #{description} (HTTP #{status})"}

        {:error, {status, description}} when is_binary(description) ->
          {:error, "Failed to send media group: #{description} (HTTP #{status})"}

        {:error, error} ->
          {:error, "Failed to send media group: #{inspect(error)}"}
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

  defp validate_media(%{media: media}) when is_list(media) do
    cond do
      length(media) < 2 ->
        {:error, "Media group must contain at least 2 items"}
      length(media) > 10 ->
        {:error, "Media group cannot contain more than 10 items"}
      Enum.all?(media, &valid_media_item?/1) ->
        {:ok, media}
      true ->
        {:error, "Invalid media items in the group"}
    end
  end
  defp validate_media(_), do: {:error, "Missing or invalid media"}

  defp valid_media_item?(%{type: type, media: media})
       when is_binary(type) and is_binary(media) and type in ["photo", "video", "audio", "document"],
       do: true
  defp valid_media_item?(_), do: false
end
