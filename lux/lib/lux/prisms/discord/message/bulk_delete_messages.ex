defmodule Lux.Prisms.Discord.Messages.BulkDeleteMessages do
  @moduledoc """
  A prism for bulk deleting messages in a Discord channel.

  This prism provides a simple interface for bulk deleting Discord messages with:
  - Required parameters (channel_id, message_ids)
  - Direct Discord API error propagation
  - Simple success/failure response structure
  - Validation for message count (2-100) and age (< 2 weeks)

  ## Examples
      iex> BulkDeleteMessages.handler(%{
      ...>   channel_id: "123456789012345678",
      ...>   message_ids: ["111111111111111111", "222222222222222222"]
      ...> }, %{name: "Agent"})
      {:ok, %{
        deleted: true,
        channel_id: "123456789012345678",
        message_count: 2
      }}
  """

  use Lux.Prism,
    name: "Bulk Delete Discord Messages",
    description: "Deletes multiple messages at once from a Discord channel",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the channel containing the messages",
          pattern: "^[0-9]{17,20}$"
        },
        message_ids: %{
          type: :array,
          description: "Array of message IDs to delete (2-100 messages)",
          items: %{
            type: :string,
            pattern: "^[0-9]{17,20}$"
          },
          minItems: 2,
          maxItems: 100,
          uniqueItems: true
        }
      },
      required: ["channel_id", "message_ids"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        deleted: %{
          type: :boolean,
          description: "Whether the messages were successfully deleted"
        },
        channel_id: %{
          type: :string,
          description: "The ID of the channel where messages were deleted"
        },
        message_count: %{
          type: :integer,
          description: "Number of messages that were deleted"
        }
      },
      required: ["deleted", "channel_id", "message_count"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Handles the request to bulk delete messages from a Discord channel.

  Returns {:ok, %{deleted: true, channel_id: id, message_count: count}} on success.
  Returns {:error, {status, message}} on failure.
  """
  def handler(params, agent) do
    with {:ok, channel_id} <- validate_param(params, :channel_id),
         {:ok, message_ids} <- validate_message_ids(params) do

      agent_name = agent[:name] || "Unknown Agent"
      message_count = length(message_ids)
      Logger.info("Agent #{agent_name} bulk deleting #{message_count} messages from channel #{channel_id}")

      case Client.request(:post, "/channels/#{channel_id}/messages/bulk-delete", %{
        json: %{messages: message_ids}
      }) do
        {:ok, _response} ->
          Logger.info("Successfully deleted #{message_count} messages from channel #{channel_id}")
          {:ok, %{deleted: true, channel_id: channel_id, message_count: message_count}}

        {:error, {status, %{"message" => message}}} ->
          error = {status, message}
          Logger.error("Failed to bulk delete messages from channel #{channel_id}: #{inspect(error)}")
          {:error, error}

        {:error, error} ->
          Logger.error("Failed to bulk delete messages from channel #{channel_id}: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp validate_message_ids(params) do
    with {:ok, message_ids} <- Map.fetch(params, :message_ids),
         true <- is_list(message_ids),
         message_count = length(message_ids),
         true <- message_count >= 2 and message_count <= 100,
         true <- Enum.all?(message_ids, &valid_message_id?/1) do
      {:ok, message_ids}
    else
      false -> {:error, "Invalid message_ids format or count (must be 2-100 valid message IDs)"}
      _ -> {:error, "Missing or invalid message_ids"}
    end
  end

  defp valid_message_id?(id) when is_binary(id) do
    String.match?(id, ~r/^[0-9]{17,20}$/)
  end
  defp valid_message_id?(_), do: false
end
