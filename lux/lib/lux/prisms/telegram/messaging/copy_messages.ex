defmodule Lux.Prisms.Telegram.Messages.CopyMessages do
  @moduledoc """
  A prism for copying multiple messages at once via the Telegram Bot API.

  This prism provides a simple interface to copy a batch of messages from one chat to another.
  Unlike forwarding, copied messages don't have a link to the original messages.
  Album grouping is kept for copied messages.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /copyMessages
  - Supports required parameters (chat_id, from_chat_id, message_ids) and optional parameters
  - Returns an array of message_ids of the new messages on success
  - Preserves original Telegram API errors for better error handling by LLMs

  ## Examples

      # Copy multiple messages
      iex> CopyMessages.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   from_chat_id: 987_654_321,
      ...>   message_ids: [42, 43, 44]
      ...> }, %{name: "Agent"})
      {:ok, %{copied: true, message_ids: [123, 124, 125], from_chat_id: 987_654_321, chat_id: 123_456_789}}

      # Copy multiple messages silently (without notification)
      iex> CopyMessages.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   from_chat_id: 987_654_321,
      ...>   message_ids: [42, 43, 44],
      ...>   disable_notification: true
      ...> }, %{name: "Agent"})
      {:ok, %{copied: true, message_ids: [123, 124, 125], from_chat_id: 987_654_321, chat_id: 123_456_789}}

      # Copy multiple messages without their captions
      iex> CopyMessages.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   from_chat_id: 987_654_321,
      ...>   message_ids: [42, 43, 44],
      ...>   remove_caption: true
      ...> }, %{name: "Agent"})
      {:ok, %{copied: true, message_ids: [123, 124, 125], from_chat_id: 987_654_321, chat_id: 123_456_789}}
  """

  use Lux.Prism,
    name: "Copy Multiple Telegram Messages",
    description: "Copies multiple messages from one chat to another via the Telegram Bot API",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat or username of the target channel"
        },
        message_thread_id: %{
          type: :integer,
          description: "Unique identifier for the target message thread (topic) of the forum; for forum supergroups only"
        },
        from_chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the chat where the original messages were sent"
        },
        message_ids: %{
          type: :array,
          description: "A JSON-serialized list of 1-100 identifiers of messages in the chat from_chat_id to copy. The identifiers must be specified in a strictly increasing order."
        },
        disable_notification: %{
          type: :boolean,
          description: "Sends the messages silently. Users will receive a notification with no sound."
        },
        protect_content: %{
          type: :boolean,
          description: "Protects the contents of the sent messages from forwarding and saving"
        },
        remove_caption: %{
          type: :boolean,
          description: "Pass True to copy the messages without their captions"
        }
      },
      required: ["chat_id", "from_chat_id", "message_ids"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        copied: %{
          type: :boolean,
          description: "Whether the messages were successfully copied"
        },
        message_ids: %{
          type: :array,
          description: "Array of identifiers of the new messages in the target chat"
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
      required: ["copied", "message_ids"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to copy multiple messages from one chat to another.

  This implementation:
  - Makes a direct request to Telegram Bot API using the Client module
  - Returns success/failure responses without additional error transformation
  - Logs the operation for monitoring purposes
  """
  def handler(params, agent) do
    with {:ok, chat_id} <- validate_param(params, :chat_id),
         {:ok, from_chat_id} <- validate_param(params, :from_chat_id),
         {:ok, message_ids} <- validate_message_ids(params) do

      agent_name = agent[:name] || "Unknown Agent"
      message_count = length(message_ids)
      Logger.info("Agent #{agent_name} copying #{message_count} messages from chat #{from_chat_id} to chat #{chat_id}")

      # Build the request body
      request_body = Map.take(params, [:chat_id, :message_thread_id, :from_chat_id, :message_ids,
                              :disable_notification, :protect_content, :remove_caption])

      # Prepare request options
      request_opts = %{json: request_body}

      case Client.request(:post, "/copyMessages", request_opts) do
        {:ok, %{"result" => new_message_ids}} when is_list(new_message_ids) ->
          Logger.info("Successfully copied #{message_count} messages from chat #{from_chat_id} to chat #{chat_id}")
          {:ok, %{
            copied: true,
            message_ids: Enum.map(new_message_ids, fn msg -> msg["message_id"] end),
            from_chat_id: from_chat_id,
            chat_id: chat_id
          }}

        {:error, {status, %{"description" => description}}} ->
          error = "Failed to copy messages: #{description} (HTTP #{status})"
          {:error, error}

        {:error, {status, description}} when is_binary(description) ->
          error = "Failed to copy messages: #{description} (HTTP #{status})"
          {:error, error}

        {:error, error} ->
          {:error, "Failed to copy messages: #{inspect(error)}"}
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

  defp validate_message_ids(params) do
    case Map.fetch(params, :message_ids) do
      {:ok, message_ids} when is_list(message_ids) ->
        validate_message_ids_length(message_ids)
      _ ->
        {:error, "Missing or invalid message_ids"}
    end
  end

  defp validate_message_ids_length(message_ids) do
    if length(message_ids) >= 1 and length(message_ids) <= 100 do
      validate_message_ids_content(message_ids)
    else
      {:error, "message_ids must contain between 1 and 100 items"}
    end
  end

  defp validate_message_ids_content(message_ids) do
    if Enum.all?(message_ids, &is_integer/1) do
      validate_message_ids_order(message_ids)
    else
      {:error, "All message_ids must be integers"}
    end
  end

  defp validate_message_ids_order(message_ids) do
    if message_ids == Enum.sort(message_ids) do
      {:ok, message_ids}
    else
      {:error, "message_ids must be specified in a strictly increasing order"}
    end
  end
end
