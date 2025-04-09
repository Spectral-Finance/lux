defmodule Lux.Prisms.Telegram.Interactive.SendAnimation do
  @moduledoc """
  A prism for sending animations (GIFs) via the Telegram Bot API.

  This prism provides a simple interface to send animations to Telegram chats.
  It uses the Telegram Bot API to send animations either by URL, file ID, or local file.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /sendAnimation
  - Supports required parameters (chat_id, animation) and optional parameters like caption
  - Returns the sent message data on success
  - Preserves original Telegram API errors for better error handling by LLMs

  ## Examples

      # Send an animation by URL
      iex> SendAnimation.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   animation: "https://example.com/animation.gif",
      ...>   caption: "Check out this GIF"
      ...> }, %{name: "Agent"})
      {:ok, %{sent: true, message_id: 42, chat_id: 123_456_789, animation: "https://example.com/animation.gif"}}

      # Send an animation with markdown formatting in caption
      iex> SendAnimation.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   animation: "https://example.com/animation.gif",
      ...>   caption: "*Bold* and _italic_ caption",
      ...>   parse_mode: "Markdown"
      ...> }, %{name: "Agent"})
      {:ok, %{sent: true, message_id: 42, chat_id: 123_456_789, animation: "https://example.com/animation.gif"}}
  """

  use Lux.Prism,
    name: "Send Telegram Animation",
    description: "Sends animations (GIFs) via the Telegram Bot API",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat or username of the target channel"
        },
        animation: %{
          type: :string,
          description: "Animation to send. Pass a file_id as String to send an animation that exists on the Telegram servers, or pass an HTTP URL as a String for Telegram to get an animation from the Internet"
        },
        duration: %{
          type: :integer,
          description: "Duration of the animation in seconds"
        },
        width: %{
          type: :integer,
          description: "Animation width"
        },
        height: %{
          type: :integer,
          description: "Animation height"
        },
        thumbnail: %{
          type: :string,
          description: "Thumbnail of the file sent; can be ignored if thumbnail generation for the file is supported server-side"
        },
        caption: %{
          type: :string,
          description: "Animation caption, 0-1024 characters after entities parsing"
        },
        parse_mode: %{
          type: :string,
          description: "Mode for parsing entities in the animation caption",
          enum: ["Markdown", "MarkdownV2", "HTML"]
        },
        caption_entities: %{
          type: :array,
          description: "A JSON-serialized list of special entities that appear in the caption"
        },
        has_spoiler: %{
          type: :boolean,
          description: "Pass True if the animation needs to be covered with a spoiler animation"
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
      required: ["chat_id", "animation"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        sent: %{
          type: :boolean,
          description: "Whether the animation was successfully sent"
        },
        message_id: %{
          type: :integer,
          description: "Identifier of the sent message"
        },
        chat_id: %{
          type: [:string, :integer],
          description: "Identifier of the target chat"
        },
        animation: %{
          type: :string,
          description: "The animation that was sent"
        },
        caption: %{
          type: :string,
          description: "Caption for the animation, if provided"
        }
      },
      required: ["sent", "message_id"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to send an animation to a Telegram chat.

  This implementation:
  - Makes a direct request to Telegram Bot API using the Client module
  - Returns success/failure responses without additional error transformation
  - Logs the operation for monitoring purposes
  """
  def handler(params, agent) do
    with {:ok, chat_id} <- validate_param(params, :chat_id),
         {:ok, animation} <- validate_param(params, :animation) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} sending animation to chat #{chat_id}")

      # Build the request body
      request_body = Map.take(params, [:chat_id, :animation, :duration, :width,
                              :height, :thumbnail, :caption, :parse_mode,
                              :caption_entities, :has_spoiler, :disable_notification,
                              :protect_content, :reply_to_message_id,
                              :allow_sending_without_reply, :reply_markup])

      # Prepare request options
      request_opts = %{json: request_body}

      case Client.request(:post, "/sendAnimation", request_opts) do
        {:ok, %{"result" => result}} when is_map(result) ->
          Logger.info("Successfully sent animation to chat #{chat_id}")

          # Extract caption for the response if it exists
          caption = Map.get(params, :caption)

          {:ok, %{
            sent: true,
            message_id: result["message_id"],
            chat_id: chat_id,
            animation: animation,
            caption: caption
          }}

        {:error, {status, %{"description" => description}}} ->
          {:error, "Failed to send animation: #{description} (HTTP #{status})"}

        {:error, {status, description}} when is_binary(description) ->
          {:error, "Failed to send animation: #{description} (HTTP #{status})"}

        {:error, error} ->
          {:error, "Failed to send animation: #{inspect(error)}"}
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
