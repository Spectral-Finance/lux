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

      # Build the request body with all permitted parameters
      request_body = params
                     |> Map.take([:chat_id, :from_chat_id, :message_id, 
                                  :disable_notification, :protect_content])
                     |> transform_param_types()

      # Prepare request options
      request_opts = %{json: request_body}
      
      # Add plug option for testing if provided
      request_opts = if Map.has_key?(params, :plug) do
        Map.put(request_opts, :plug, params.plug)
      else
        request_opts
      end

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

  # Transform parameters to the correct types expected by the Telegram API
  defp transform_param_types(params) do
    params
    |> Enum.reduce(%{}, fn
      # Skip "schema" and other non-desired attributes
      {key, _value}, acc when key in ["schema", "lux"] ->
        acc
      {key, value}, acc when is_binary(value) and key in [:chat_id, :from_chat_id] ->
        # Try to convert string chat_id to integer if it's numeric
        case Integer.parse(value) do
          {int_value, ""} -> Map.put(acc, stringify_key(key), int_value)
          _ -> Map.put(acc, stringify_key(key), value)
        end
      # Handle nested maps recursively
      {key, value}, acc when is_map(value) ->
        Map.put(acc, stringify_key(key), transform_param_types(value))
      # Handle lists that might contain maps
      {key, value}, acc when is_list(value) ->
        Map.put(acc, stringify_key(key), Enum.map(value, &transform_list_item/1))
      # Convert any other pairs ensuring the key is a string
      {key, value}, acc -> Map.put(acc, stringify_key(key), value)
    end)
  end

  # Helper function to stringify keys
  defp stringify_key(key) when is_atom(key), do: Atom.to_string(key)
  defp stringify_key(key) when is_binary(key), do: key
  defp stringify_key(key), do: "#{key}"

  # Handle non-list items
  defp transform_list_item(item) do
    if is_map(item), do: transform_param_types(item), else: item
  end
end 