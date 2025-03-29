defmodule Lux.Prisms.Telegram.Messages.DeleteMessage do
  @moduledoc """
  A prism for deleting messages via the Telegram Bot API.

  This prism provides a simple interface to delete messages from Telegram chats.
  It uses the Telegram Bot API to delete messages that the bot has permission to delete.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /deleteMessage
  - Supports required parameters (chat_id, message_id)
  - Returns a simple success response on successful deletion
  - Preserves original Telegram API errors for better error handling by LLMs

  ## Examples

      # Delete a message
      iex> DeleteMessage.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   message_id: 42
      ...> }, %{name: "Agent"})
      {:ok, %{deleted: true, message_id: 42, chat_id: 123_456_789}}

      # Error handling (passed through from Telegram API)
      iex> DeleteMessage.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   message_id: 42
      ...> }, %{name: "Agent"})
      {:error, "Failed to delete message: Bad Request: message to delete not found (HTTP 400)"}
  """

  use Lux.Prism,
    name: "Delete Telegram Message",
    description: "Deletes a message from a Telegram chat",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat or username of the target channel"
        },
        message_id: %{
          type: :integer,
          description: "Identifier of the message to delete"
        }
      },
      required: ["chat_id", "message_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        deleted: %{
          type: :boolean,
          description: "Whether the message was successfully deleted"
        },
        message_id: %{
          type: [:string, :integer],
          description: "The ID of the deleted message"
        },
        chat_id: %{
          type: [:string, :integer],
          description: "The chat ID where the message was deleted"
        }
      },
      required: ["deleted"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to delete a message from a Telegram chat.

  This implementation:
  - Makes a direct request to Telegram Bot API using the Client module
  - Returns success/failure responses without additional error transformation
  - Logs the operation for monitoring purposes
  """
  def handler(params, agent) do
    with {:ok, chat_id} <- validate_param(params, :chat_id),
         {:ok, message_id} <- validate_param(params, :message_id, :integer) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} deleting message #{message_id} from chat #{chat_id}")

      # Build the request body with all permitted parameters
      request_body = params
                     |> Map.take([:chat_id, :message_id])
                     |> transform_param_types()

      # Prepare request options
      request_opts = %{json: request_body}
      
      # Add plug option for testing if provided
      request_opts = if Map.has_key?(params, :plug) do
        Map.put(request_opts, :plug, params.plug)
      else
        request_opts
      end

      case Client.request(:post, "/deleteMessage", request_opts) do
        {:ok, %{"result" => true}} ->
          Logger.info("Successfully deleted message #{message_id} from chat #{chat_id}")
          {:ok, %{
            deleted: true, 
            message_id: message_id, 
            chat_id: chat_id
          }}
        
        {:error, {status, %{"description" => description}}} ->
          {:error, "Failed to delete message: #{description} (HTTP #{status})"}
          
        {:error, error} ->
          {:error, "Failed to delete message: #{inspect(error)}"}
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
      {key, value}, acc when is_binary(value) and key in [:chat_id] -> 
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