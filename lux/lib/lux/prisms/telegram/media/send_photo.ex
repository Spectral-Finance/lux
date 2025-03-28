defmodule Lux.Prisms.Telegram.Media.SendPhoto do
  @moduledoc """
  A prism for sending photos via the Telegram Bot API.

  This prism provides a simple interface to send photos to Telegram chats.
  It uses the Telegram Bot API to send photos either by URL or file ID.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /sendPhoto
  - Supports required parameters (chat_id, photo) and optional parameters like caption
  - Returns the sent message data on success
  - Preserves original Telegram API errors for better error handling by LLMs

  ## Examples

      # Send a photo by URL
      iex> SendPhoto.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   photo: "https://example.com/photo.jpg",
      ...>   caption: "A beautiful photo"
      ...> }, %{name: "Agent"})
      {:ok, %{sent: true, message_id: 42, chat_id: 123_456_789, photo: "https://example.com/photo.jpg"}}

      # Send a photo with markdown formatting in caption
      iex> SendPhoto.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   photo: "https://example.com/photo.jpg",
      ...>   caption: "*Bold* and _italic_ caption",
      ...>   parse_mode: "Markdown"
      ...> }, %{name: "Agent"})
      {:ok, %{sent: true, message_id: 42, chat_id: 123_456_789, photo: "https://example.com/photo.jpg"}}
  """

  use Lux.Prism,
    name: "Send Telegram Photo",
    description: "Sends photos via the Telegram Bot API",
    input_schema: %{
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
    },
    output_schema: %{
      type: :object,
      properties: %{
        sent: %{
          type: :boolean,
          description: "Whether the photo was successfully sent"
        },
        message_id: %{
          type: :integer,
          description: "Identifier of the sent message"
        },
        chat_id: %{
          type: [:string, :integer],
          description: "Identifier of the target chat"
        },
        photo: %{
          type: :string,
          description: "The photo that was sent"
        },
        caption: %{
          type: :string,
          description: "Caption for the photo, if provided"
        }
      },
      required: ["sent", "message_id"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to send a photo to a Telegram chat.

  This implementation:
  - Makes a direct request to Telegram Bot API using the Client module
  - Returns success/failure responses without additional error transformation
  - Logs the operation for monitoring purposes
  """
  def handler(params, agent) do
    with {:ok, chat_id} <- validate_param(params, :chat_id),
         {:ok, photo} <- validate_param(params, :photo) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} sending photo to chat #{chat_id}")

      # Build the request body with all permitted parameters
      request_body = params
                     |> Map.take([:chat_id, :photo, :caption, :parse_mode, 
                                  :caption_entities, :disable_notification,
                                  :protect_content, :reply_to_message_id,
                                  :allow_sending_without_reply, :reply_markup])
                     |> transform_param_types()

      # Prepare request options
      request_opts = %{json: request_body}
      
      # Add plug option for testing if provided
      request_opts = if Map.has_key?(params, :plug) do
        Map.put(request_opts, :plug, params.plug)
      else
        request_opts
      end

      case Client.request(:post, "/sendPhoto", request_opts) do
        {:ok, %{"result" => result}} when is_map(result) ->
          Logger.info("Successfully sent photo to chat #{chat_id}")
          
          # Extract caption for the response if it exists
          caption = Map.get(params, :caption)
          
          {:ok, %{
            sent: true, 
            message_id: result["message_id"], 
            chat_id: chat_id,
            photo: photo,
            caption: caption
          }}
        
        {:error, {status, %{"description" => description}}} ->
          {:error, "Failed to send photo: #{description} (HTTP #{status})"}
          
        {:error, error} ->
          {:error, "Failed to send photo: #{inspect(error)}"}
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

  # Transform parameters to the correct types expected by the Telegram API
  defp transform_param_types(params) do
    params
    |> Enum.map(fn
      {key, value} when is_binary(value) and key in [:chat_id] -> 
        # Try to convert string chat_id to integer if it's numeric
        case Integer.parse(value) do
          {int_value, ""} -> {stringify_key(key), int_value}
          _ -> {stringify_key(key), value}
        end
      # Handle nested maps recursively
      {key, value} when is_map(value) ->
        {stringify_key(key), transform_param_types(value)}
      # Handle lists that might contain maps
      {key, value} when is_list(value) ->
        {stringify_key(key), Enum.map(value, &transform_list_item/1)}
      # Convert any other pairs ensuring the key is a string
      {key, value} -> {stringify_key(key), value}
    end)
    |> Enum.into(%{})
  end

  # Helper function to stringify keys
  defp stringify_key(key) when is_atom(key), do: Atom.to_string(key)
  defp stringify_key(key) when is_binary(key), do: key
  defp stringify_key(key), do: "#{key}"

  # Helper function to transform items in a list
  defp transform_list_item(item) when is_map(item), do: transform_param_types(item)
  defp transform_list_item(item), do: item
end 