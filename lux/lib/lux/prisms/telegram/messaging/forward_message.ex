defmodule Lux.Prisms.Telegram.Messages.ForwardMessage do
  @moduledoc """
  A prism for forwarding messages via the Telegram Bot API.

  This prism provides a simple interface to forward messages from one chat to another.
  Unlike copying, forwarded messages have a link to the original message.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /forwardMessage
  - Supports required parameters (chat_id, from_chat_id, message_id) and optional parameters
  - Returns the message_id of the new message on success
  - Preserves original Telegram API errors for better error handling by LLMs

  ## Examples

      # Forward a message
      iex> ForwardMessage.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   from_chat_id: 987_654_321,
      ...>   message_id: 42
      ...> }, %{name: "Agent"})
      {:ok, %{forwarded: true, message_id: 123, from_chat_id: 987_654_321, chat_id: 123_456_789}}

      # Forward a message silently (without notification)
      iex> ForwardMessage.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   from_chat_id: 987_654_321,
      ...>   message_id: 42,
      ...>   disable_notification: true
      ...> }, %{name: "Agent"})
      {:ok, %{forwarded: true, message_id: 123, from_chat_id: 987_654_321, chat_id: 123_456_789}}

      # Forward a message with content protection
      iex> ForwardMessage.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   from_chat_id: 987_654_321,
      ...>   message_id: 42,
      ...>   protect_content: true
      ...> }, %{name: "Agent"})
      {:ok, %{forwarded: true, message_id: 123, from_chat_id: 987_654_321, chat_id: 123_456_789}}
  """

  use Lux.Prism,
    name: "Forward Telegram Message",
    description: "Forwards a message from one chat to another via the Telegram Bot API",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat or username of the target channel"
        },
        from_chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the chat where the original message was sent"
        },
        message_id: %{
          type: :integer,
          description: "Message identifier in the chat specified in from_chat_id"
        },
        disable_notification: %{
          type: :boolean,
          description: "Sends the message silently. Users will receive a notification with no sound."
        },
        protect_content: %{
          type: :boolean,
          description: "Protects the contents of the forwarded message from forwarding and saving"
        }
      },
      required: ["chat_id", "from_chat_id", "message_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        forwarded: %{
          type: :boolean,
          description: "Whether the message was successfully forwarded"
        },
        message_id: %{
          type: :integer,
          description: "Identifier of the new message in the target chat"
        },
        from_chat_id: %{
          type: [:string, :integer],
          description: "Identifier of the source chat"
        },
        chat_id: %{
          type: [:string, :integer],
          description: "Identifier of the target chat"
        }
      },
      required: ["forwarded", "message_id"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to forward a message from one chat to another.

  This implementation:
  - Makes a direct request to Telegram Bot API using the Client module
  - Returns success/failure responses without additional error transformation
  - Logs the operation for monitoring purposes
  """
  def handler(params, agent) do
    with {:ok, chat_id} <- validate_param(params, :chat_id),
         {:ok, from_chat_id} <- validate_param(params, :from_chat_id),
         {:ok, message_id} <- validate_param(params, :message_id, :integer) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} forwarding message #{message_id} from chat #{from_chat_id} to chat #{chat_id}")

      # Build the request body
      request_body = Map.take(params, [:chat_id, :from_chat_id, :message_id,
                               :disable_notification, :protect_content])

      # Prepare request options
      request_opts = %{json: request_body}

      case Client.request(:post, "/forwardMessage", request_opts) do
        {:ok, %{"result" => %{"message_id" => new_message_id}}} ->
          Logger.info("Successfully forwarded message #{message_id} from chat #{from_chat_id} to chat #{chat_id}")
          {:ok, %{
            forwarded: true,
            message_id: new_message_id,
            from_chat_id: from_chat_id,
            chat_id: chat_id
          }}

        {:error, {status, %{"description" => description}}} ->
          error = "Failed to forward message: #{description} (HTTP #{status})"
          {:error, error}

        {:error, error} ->
          {:error, "Failed to forward message: #{inspect(error)}"}
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
