defmodule Lux.Prisms.Telegram.Chat.SetChatPhoto do
  @moduledoc """
  A prism for setting chat photos via the Telegram Bot API.

  This prism provides a simple interface to set a new profile photo for a chat.
  It uses the Telegram Bot API to upload and set chat profile photos.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /setChatPhoto
  - Supports required parameters (chat_id, photo)
  - Returns a simple success response on successful setting
  - Preserves original Telegram API errors for better error handling by LLMs

  ## Examples

      # Set a chat photo by URL
      iex> SetChatPhoto.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   photo: "https://example.com/chat_photo.jpg"
      ...> }, %{name: "Agent"})
      {:ok, %{success: true, chat_id: 123_456_789}}

      # Set a chat photo for a channel
      iex> SetChatPhoto.handler(%{
      ...>   chat_id: "@mychannel",
      ...>   photo: "https://example.com/channel_photo.jpg"
      ...> }, %{name: "Agent"})
      {:ok, %{success: true, chat_id: "@mychannel"}}
  """

  use Lux.Prism,
    name: "Set Telegram Chat Photo",
    description: "Sets a new profile photo for a chat via the Telegram Bot API",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat or username of the target channel (in the format @channelusername)"
        },
        photo: %{
          type: :string,
          description: "New chat photo. Pass a file_id as String to send a photo that exists on the Telegram servers, or pass an HTTP URL as a String for Telegram to get a photo from the Internet"
        }
      },
      required: ["chat_id", "photo"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        success: %{
          type: :boolean,
          description: "Whether the chat photo was successfully set"
        },
        chat_id: %{
          type: [:string, :integer],
          description: "Identifier of the chat where the photo was set"
        }
      },
      required: ["success", "chat_id"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to set a new profile photo for a chat.

  This implementation:
  - Makes a direct request to Telegram Bot API using the Client module
  - Returns success/failure responses without additional error transformation
  - Logs the operation for monitoring purposes
  """
  def handler(params, agent) do
    with {:ok, chat_id} <- validate_param(params, :chat_id),
         {:ok, photo} <- validate_param(params, :photo) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} setting photo for chat #{chat_id}")

      # Build the request body
      request_body = %{
        chat_id: chat_id,
        photo: photo
      }

      # Prepare request options
      request_opts = %{json: request_body}

      case Client.request(:post, "/setChatPhoto", request_opts) do
        {:ok, %{"result" => true}} ->
          Logger.info("Successfully set photo for chat #{chat_id}")
          {:ok, %{
            success: true,
            chat_id: chat_id
          }}

        {:error, {status, %{"description" => description}}} ->
          {:error, "Failed to set chat photo: #{description} (HTTP #{status})"}

        {:error, {status, description}} when is_binary(description) ->
          {:error, "Failed to set chat photo: #{description} (HTTP #{status})"}

        {:error, error} ->
          {:error, "Failed to set chat photo: #{inspect(error)}"}
      end
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      {:ok, value} when is_integer(value) -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
