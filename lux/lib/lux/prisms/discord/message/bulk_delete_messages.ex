defmodule Lux.Prisms.Discord.Messages.BulkDeleteMessages do
  @moduledoc """
  A prism for bulk deleting messages in a Discord channel.

  Uses the Discord bulk delete endpoint which can delete 2-100 messages at once.
  Messages older than 14 days cannot be bulk deleted.

  ## Examples
      iex> BulkDeleteMessages.handler(%{
      ...>   channel_id: "123456789",
      ...>   message_ids: ["111111111111111111", "222222222222222222"]
      ...> }, %{name: "Agent"})
      {:ok, %{
        deleted: true,
        count: 2,
        channel_id: "123456789"
      }}
  """

  use Lux.Prism,
    name: "Bulk Delete Discord Messages",
    description: "Deletes multiple messages in a Discord channel (2-100 messages)",
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
          description: "Array of message IDs to delete (2-100)",
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
        deleted: %{
          type: :boolean,
          description: "Whether the messages were successfully deleted"
        },
        count: %{
          type: :integer,
          description: "Number of messages deleted"
        },
        channel_id: %{
          type: :string,
          description: "The ID of the channel"
        }
      },
      required: ["deleted", "count", "channel_id"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Handles the request to bulk delete messages in a Discord channel.

  Returns {:ok, %{deleted: true, count: count, channel_id: channel_id}} on success.
  Returns {:error, reason} on failure.
  """
  def handler(params, agent) do
    with {:ok, channel_id} <- validate_param(params, :channel_id),
         {:ok, message_ids} <- validate_message_ids(params) do

      agent_name = agent[:name] || "Unknown Agent"
      count = length(message_ids)
      Logger.info("Agent #{agent_name} bulk deleting #{count} messages in channel #{channel_id}")

      case Client.request(:post, "/channels/#{channel_id}/messages/bulk-delete", %{
        json: %{messages: message_ids}
      }) do
        {:ok, _} ->
          Logger.info("Successfully bulk deleted #{count} messages in channel #{channel_id}")
          {:ok, %{deleted: true, count: count, channel_id: channel_id}}
        {:error, {status, %{"message" => message}}} ->
          error = {status, message}
          Logger.error("Failed to bulk delete messages in channel #{channel_id}: #{inspect(error)}")
          {:error, error}
        {:error, error} ->
          Logger.error("Failed to bulk delete messages in channel #{channel_id}: #{inspect(error)}")
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
    case Map.fetch(params, :message_ids) do
      {:ok, ids} when is_list(ids) and length(ids) >= 2 and length(ids) <= 100 ->
        if Enum.all?(ids, &is_binary/1), do: {:ok, ids}, else: {:error, "All message_ids must be strings"}
      {:ok, ids} when is_list(ids) ->
        {:error, "message_ids must contain between 2 and 100 IDs, got #{length(ids)}"}
      _ ->
        {:error, "Missing or invalid message_ids"}
    end
  end
end
