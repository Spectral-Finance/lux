defmodule Lux.Prisms.Telegram.Messages.SendMessage do
  @moduledoc """
  A prism for sending text messages via the Telegram Bot API.

  This prism provides a simple interface to send text messages to Telegram chats.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /sendMessage
  - Supports required parameters (chat_id, text) and optional parameters
  - Returns the message_id of the sent message on success
  - Preserves original Telegram API errors for better error handling by LLMs

  ## Examples

      # Send a simple message
      iex> SendMessage.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   text: "Hello from Lux!"
      ...> }, %{name: "Agent"})
      {:ok, %{sent: true, message_id: 123, chat_id: 123_456_789, text: "Hello from Lux!"}}

      # Send a message with markdown formatting
      iex> SendMessage.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   text: "*Bold* and _italic_ text",
      ...>   parse_mode: "Markdown"
      ...> }, %{name: "Agent"})
      {:ok, %{sent: true, message_id: 123, chat_id: 123_456_789, text: "*Bold* and _italic_ text"}}

      # Send a message silently (without notification)
      iex> SendMessage.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   text: "Silent message",
      ...>   disable_notification: true
      ...> }, %{name: "Agent"})
      {:ok, %{sent: true, message_id: 123, chat_id: 123_456_789, text: "Silent message"}}
  """

  use Lux.Prism,
    name: "Send Telegram Message",
    description: "Sends a text message to a chat via the Telegram Bot API",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat or username of the target channel"
        },
        text: %{
          type: :string,
          description: "Text of the message to be sent"
        },
        parse_mode: %{
          type: :string,
          description: "Mode for parsing entities in the message text",
          enum: ["Markdown", "MarkdownV2", "HTML"]
        },
        disable_web_page_preview: %{
          type: :boolean,
          description: "Disables link previews for links in this message"
        },
        disable_notification: %{
          type: :boolean,
          description: "Sends the message silently. Users will receive a notification with no sound."
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
        }
      },
      required: ["chat_id", "text"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        sent: %{
          type: :boolean,
          description: "Whether the message was successfully sent"
        },
        message_id: %{
          type: :integer,
          description: "Identifier of the sent message"
        },
        chat_id: %{
          type: [:string, :integer],
          description: "Identifier of the target chat"
        },
        text: %{
          type: :string,
          description: "Text of the sent message"
        }
      },
      required: ["sent", "message_id", "text"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to send a text message to a chat.

  This implementation:
  - Makes a direct request to Telegram Bot API using the Client module
  - Returns success/failure responses without additional error transformation
  - Logs the operation for monitoring purposes
  """
  def handler(params, agent) do
    with {:ok, chat_id} <- validate_param(params, :chat_id),
         {:ok, text} <- validate_param(params, :text) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} sending message to chat #{chat_id}")

      # Build the request body with all permitted parameters
      request_body = params
                     |> Map.take([:chat_id, :text, :parse_mode, :disable_web_page_preview,
                                  :disable_notification, :protect_content, 
                                  :reply_to_message_id, :allow_sending_without_reply])
                     |> transform_param_types()

      # Prepare request options
      request_opts = %{json: request_body}
      
      # Add plug option for testing if provided
      request_opts = if Map.has_key?(params, :plug) do
        Map.put(request_opts, :plug, params.plug)
      else
        request_opts
      end

      case Client.request(:post, "/sendMessage", request_opts) do
        {:ok, %{"result" => %{"message_id" => new_message_id}}} ->
          Logger.info("Successfully sent message to chat #{chat_id}")
          {:ok, %{
            sent: true, 
            message_id: new_message_id, 
            chat_id: chat_id,
            text: text
          }}
        
        {:error, {status, %{"description" => description}}} ->
          error = "Failed to send message: #{description} (HTTP #{status})"
          {:error, error}
          
        {:error, error} ->
          {:error, "Failed to send message: #{inspect(error)}"}
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
          {int_value, ""} -> {key, int_value}
          _ -> {key, value}
        end
      # Convert atom keys to strings to meet Telegram API expectations
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      {key, value} -> {key, value}
    end)
    |> Enum.into(%{})
  end
end 