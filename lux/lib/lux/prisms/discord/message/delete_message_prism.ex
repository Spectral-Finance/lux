defmodule Lux.Prisms.Discord.Messages.DeleteMessagePrism do
  @moduledoc """
  A prism for deleting Discord messages.

  This prism provides a simple interface to delete messages from Discord channels. It leverages
  the Discord API client for making requests and follows a minimalist approach by:

  - Supporting only essential parameters (channel_id, message_id)
  - Passing through Discord API errors directly for LLM interpretation
  - Providing clear success/failure responses

  ## Implementation Details

  - Uses Discord API endpoint: DELETE /channels/{channel_id}/messages/{message_id}
  - Returns a simple success response with the deletion status and message details
  - Preserves original Discord API errors for better error handling by LLMs

  ## Examples

      # Delete a message
      iex> DeleteMessagePrism.handler(%{
      ...>   channel_id: "123456789",
      ...>   message_id: "987654321"
      ...> }, %{agent: %{name: "Agent"}})
      {:ok, %{deleted: true, message_id: "987654321", channel_id: "123456789"}}

      # Error handling (passed through from Discord API)
      iex> DeleteMessagePrism.handler(%{
      ...>   channel_id: "123456789",
      ...>   message_id: "987654321"
      ...> }, %{agent: %{name: "Agent"}})
      {:error, {403, "Missing Permissions"}}
  """

  use Lux.Prism,
    name: "Delete Discord Message",
    description: "Deletes a message from a Discord channel",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the channel containing the message",
          pattern: "^[0-9]{17,20}$"
        },
        message_id: %{
          type: :string,
          description: "The ID of the message to delete",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["channel_id", "message_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        deleted: %{
          type: :boolean,
          description: "Whether the message was successfully deleted"
        },
        message_id: %{
          type: :string,
          description: "The ID of the deleted message"
        },
        channel_id: %{
          type: :string,
          description: "The channel ID where the message was deleted"
        }
      },
      required: ["deleted"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Handles the request to delete a message from a Discord channel.

  This implementation:
  - Makes a direct request to Discord API using the Client module
  - Returns success/failure responses without additional error transformation
  - Logs the operation for monitoring purposes
  """
  def handler(params, agent) do
    with {:ok, channel_id} <- validate_param(params, :channel_id),
         {:ok, message_id} <- validate_param(params, :message_id) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} deleting message #{message_id} from channel #{channel_id}")

      case Client.request(:delete, "/channels/#{channel_id}/messages/#{message_id}", %{}) do
        {:ok, _} ->
          Logger.info("Successfully deleted message #{message_id} from channel #{channel_id}")
          {:ok, %{deleted: true, message_id: message_id, channel_id: channel_id}}
        error ->
          Logger.error("Failed to delete message #{message_id} from channel #{channel_id}: #{inspect(error)}")
          error
      end
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
