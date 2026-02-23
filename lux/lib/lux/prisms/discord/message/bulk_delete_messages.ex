defmodule Lux.Prisms.Discord.Messages.BulkDeleteMessages do
  @moduledoc """
  A prism for bulk-deleting messages from a Discord channel.

  Uses Discord's bulk-delete endpoint, which can remove 2–100 messages at once.
  Messages must be fewer than 14 days old (Discord API restriction).

  ## Examples
      iex> BulkDeleteMessages.handler(%{
      ...>   channel_id: "123456789012345678",
      ...>   message_ids: ["111111111111111111", "222222222222222222"]
      ...> }, %{name: "Agent"})
      {:ok, %{deleted: true, count: 2, channel_id: "123456789012345678"}}
  """

  use Lux.Prism,
    name: "Bulk Delete Discord Messages",
    description: "Deletes 2-100 messages from a Discord channel in a single operation",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the channel to delete messages from",
          pattern: "^[0-9]{17,20}$"
        },
        message_ids: %{
          type: :array,
          description: "Array of message IDs to delete (2-100 IDs, must be <14 days old)",
          items: %{type: :string, pattern: "^[0-9]{17,20}$"},
          minItems: 2,
          maxItems: 100
        }
      },
      required: ["channel_id", "message_ids"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        deleted: %{type: :boolean, description: "Whether the messages were successfully deleted"},
        count: %{type: :integer, description: "Number of messages deleted"},
        channel_id: %{type: :string, description: "The ID of the channel"}
      },
      required: ["deleted"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, channel_id} <- validate_snowflake(params, :channel_id),
         {:ok, message_ids} <- validate_message_ids(params) do
      agent_name = agent[:name] || "Unknown Agent"
      count = length(message_ids)
      Logger.info("Agent #{agent_name} bulk-deleting #{count} messages from channel #{channel_id}")

      case Client.request(:post, "/channels/#{channel_id}/messages/bulk-delete", %{json: %{messages: message_ids}}) do
        {:ok, _} ->
          Logger.info("Successfully deleted #{count} messages from channel #{channel_id}")
          {:ok, %{deleted: true, count: count, channel_id: channel_id}}
        {:error, {status, %{"message" => message}}} ->
          Logger.error("Failed to bulk-delete messages in channel #{channel_id}: #{message}")
          {:error, {status, message}}
        {:error, error} ->
          Logger.error("Failed to bulk-delete messages in channel #{channel_id}: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  defp validate_snowflake(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp validate_message_ids(params) do
    case Map.fetch(params, :message_ids) do
      {:ok, ids} when is_list(ids) and length(ids) >= 2 and length(ids) <= 100 ->
        if Enum.all?(ids, &(is_binary(&1) and &1 != "")) do
          {:ok, ids}
        else
          {:error, "All message_ids must be non-empty strings"}
        end
      {:ok, ids} when is_list(ids) ->
        {:error, "message_ids must contain between 2 and 100 IDs, got #{length(ids)}"}
      _ ->
        {:error, "Missing or invalid message_ids"}
    end
  end
end
