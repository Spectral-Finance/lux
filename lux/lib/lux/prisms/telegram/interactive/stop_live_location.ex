defmodule Lux.Prisms.Telegram.Interactive.StopLiveLocation do
  @moduledoc """
  A prism for stopping live location updates via the Telegram Bot API.

  This prism provides a simple interface to stop updating the location of previously sent live location messages.
  It uses the Telegram Bot API to permanently end a live location sharing session.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /stopMessageLiveLocation
  - Supports stopping live location for messages identified by chat_id and message_id or by inline_message_id
  - Returns the updated message or success status on success
  - Preserves original Telegram API errors for better error handling by LLMs

  ## Examples

      # Stop a live location in a chat
      iex> StopLiveLocation.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   message_id: 42
      ...> }, %{name: "Agent"})
      {:ok, %{stopped: true, message_id: 42, chat_id: 123_456_789}}

      # Stop a live location for an inline message
      iex> StopLiveLocation.handler(%{
      ...>   inline_message_id: "CAAqrxJRAqABAZaiqJ4sAJtvlCQI"
      ...> }, %{name: "Agent"})
      {:ok, %{stopped: true, inline_message_id: "CAAqrxJRAqABAZaiqJ4sAJtvlCQI"}}
  """

  use Lux.Prism,
    name: "Stop Telegram Live Location",
    description: "Stops live location updates for messages via the Telegram Bot API",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Required if inline_message_id is not specified. Unique identifier for the target chat or username of the target channel"
        },
        message_id: %{
          type: :integer,
          description: "Required if inline_message_id is not specified. Identifier of the message with live location to stop"
        },
        inline_message_id: %{
          type: :string,
          description: "Required if chat_id and message_id are not specified. Identifier of the inline message"
        },
        reply_markup: %{
          type: :object,
          description: "A JSON-serialized object for a new inline keyboard"
        }
      },
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        stopped: %{
          type: :boolean,
          description: "Whether the live location was successfully stopped"
        },
        message_id: %{
          type: :integer,
          description: "Identifier of the message with stopped live location"
        },
        chat_id: %{
          type: [:string, :integer],
          description: "Identifier of the chat"
        },
        inline_message_id: %{
          type: :string,
          description: "Identifier of the inline message"
        }
      },
      required: ["stopped"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to stop a live location message.

  This implementation:
  - Makes a direct request to Telegram Bot API using the Client module
  - Returns success/failure responses without additional error transformation
  - Logs the operation for monitoring purposes
  """
  def handler(params, agent) do
    with :ok <- validate_message_identifiers(params) do
      agent_name = agent[:name] || "Unknown Agent"
      message_identifier = get_message_identifier(params)

      Logger.info("Agent #{agent_name} stopping live location for #{message_identifier}")

      # Build the request body
      request_body = Map.take(params, [:chat_id, :message_id, :inline_message_id, :reply_markup])

      # Prepare request options
      request_opts = %{json: request_body}

      case Client.request(:post, "/stopMessageLiveLocation", request_opts) do
        {:ok, %{"result" => result}} when is_map(result) ->
          handle_successful_response(message_identifier, params)

        {:ok, %{"result" => true}} ->
          # For inline messages, we might just get a success boolean
          handle_successful_boolean_response(message_identifier, params)

        {:error, error} ->
          handle_error_response(error)
      end
    end
  end

  defp handle_successful_response(message_identifier, params) do
    Logger.info("Successfully stopped live location for #{message_identifier}")

    # Build the response based on whether it's a chat message or inline message
    response = %{stopped: true}

    {:ok, add_message_identifier_to_response(response, params)}
  end

  defp handle_successful_boolean_response(message_identifier, params) do
    Logger.info("Successfully stopped live location for #{message_identifier}")

    response = %{stopped: true}

    # Add the inline_message_id if it exists
    response = if inline_id = Map.get(params, :inline_message_id) do
      Map.put(response, :inline_message_id, inline_id)
    else
      response
    end

    {:ok, response}
  end

  defp handle_error_response(error) do
    case error do
      {status, %{"description" => description}} ->
        {:error, "Failed to stop live location: #{description} (HTTP #{status})"}

      {status, description} when is_binary(description) ->
        {:error, "Failed to stop live location: #{description} (HTTP #{status})"}

      _ ->
        {:error, "Failed to stop live location: #{inspect(error)}"}
    end
  end

  defp get_message_identifier(params) do
    case {Map.get(params, :chat_id), Map.get(params, :message_id), Map.get(params, :inline_message_id)} do
      {chat_id, message_id, nil} when not is_nil(chat_id) and not is_nil(message_id) ->
        "message_id: #{message_id} in chat: #{chat_id}"
      {nil, nil, inline_message_id} when not is_nil(inline_message_id) ->
        "inline_message: #{inline_message_id}"
      _ ->
        "unknown message"
    end
  end

  defp add_message_identifier_to_response(response, params) do
    case {Map.get(params, :chat_id), Map.get(params, :message_id), Map.get(params, :inline_message_id)} do
      {chat_id, message_id, nil} when not is_nil(chat_id) and not is_nil(message_id) ->
        response
        |> Map.put(:chat_id, chat_id)
        |> Map.put(:message_id, message_id)
      {nil, nil, inline_message_id} when not is_nil(inline_message_id) ->
        Map.put(response, :inline_message_id, inline_message_id)
      _ ->
        response
    end
  end

  defp validate_message_identifiers(params) do
    case {Map.get(params, :chat_id), Map.get(params, :message_id), Map.get(params, :inline_message_id)} do
      {chat_id, message_id, nil} when not is_nil(chat_id) and not is_nil(message_id) ->
        :ok
      {nil, nil, inline_message_id} when not is_nil(inline_message_id) ->
        :ok
      _ ->
        {:error, "Missing or invalid message identifier: Either (chat_id and message_id) or inline_message_id must be provided"}
    end
  end
end
