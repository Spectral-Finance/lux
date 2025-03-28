defmodule Lux.Prisms.Telegram.Messages.CopyMessage do
  @moduledoc """
  A prism for copying messages via the Telegram Bot API.

  This prism provides a simple interface to copy messages from one chat to another.
  Unlike forwarding, copied messages don't have a link to the original message.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /copyMessage
  - Supports required parameters (chat_id, from_chat_id, message_id) and optional parameters
  - Returns the message_id of the new message on success
  - Preserves original Telegram API errors for better error handling by LLMs

  ## Examples

      # Copy a message
      iex> CopyMessage.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   from_chat_id: 987_654_321,
      ...>   message_id: 42
      ...> }, %{name: "Agent"})
      {:ok, %{copied: true, message_id: 123, from_chat_id: 987_654_321, chat_id: 123_456_789}}

      # Copy a message silently (without notification)
      iex> CopyMessage.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   from_chat_id: 987_654_321,
      ...>   message_id: 42,
      ...>   disable_notification: true
      ...> }, %{name: "Agent"})
      {:ok, %{copied: true, message_id: 123, from_chat_id: 987_654_321, chat_id: 123_456_789}}

      # Copy a message with a new caption
      iex> CopyMessage.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   from_chat_id: 987_654_321,
      ...>   message_id: 42,
      ...>   caption: "New caption for the copied message",
      ...>   parse_mode: "Markdown"
      ...> }, %{name: "Agent"})
      {:ok, %{copied: true, message_id: 123, from_chat_id: 987_654_321, chat_id: 123_456_789}}
  """

  use Lux.Prism,
    name: "Copy Telegram Message",
    description: "Copies a message from one chat to another via the Telegram Bot API",
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
        caption: %{
          type: :string,
          description: "New caption for media, 0-1024 characters after entities parsing"
        },
        parse_mode: %{
          type: :string,
          description: "Mode for parsing entities in the new caption",
          enum: ["Markdown", "MarkdownV2", "HTML"]
        },
        disable_notification: %{
          type: :boolean,
          description: "Sends the message silently. Users will receive a notification with no sound."
        },
        protect_content: %{
          type: :boolean,
          description: "Protects the contents of the copied message from forwarding and saving"
        }
      },
      required: ["chat_id", "from_chat_id", "message_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        copied: %{
          type: :boolean,
          description: "Whether the message was successfully copied"
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
      required: ["copied", "message_id"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to copy a message from one chat to another.

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
      Logger.info("Agent #{agent_name} copying message #{message_id} from chat #{from_chat_id} to chat #{chat_id}")

      # Build the request body with all permitted parameters
      request_body = params
                     |> Map.take([:chat_id, :from_chat_id, :message_id, :caption, 
                                  :parse_mode, :disable_notification, :protect_content])
                     |> transform_param_types()

      # Prepare request options
      request_opts = %{json: request_body}
      
      # Add plug option for testing if provided
      request_opts = if Map.has_key?(params, :plug) do
        Map.put(request_opts, :plug, params.plug)
      else
        request_opts
      end

      case Client.request(:post, "/copyMessage", request_opts) do
        {:ok, %{"result" => %{"message_id" => new_message_id}}} ->
          Logger.info("Successfully copied message #{message_id} from chat #{from_chat_id} to chat #{chat_id}")
          {:ok, %{
            copied: true, 
            message_id: new_message_id, 
            from_chat_id: from_chat_id, 
            chat_id: chat_id
          }}
        
        {:error, {status, %{"description" => description}}} ->
          error = "Failed to copy message: #{description} (HTTP #{status})"
          {:error, error}
          
        {:error, error} ->
          {:error, "Failed to copy message: #{inspect(error)}"}
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
      {key, value} when is_binary(value) and key in [:chat_id, :from_chat_id] -> 
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