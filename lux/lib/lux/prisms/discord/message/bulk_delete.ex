defmodule Lux.Prisms.Discord.Message.BulkDelete do
  @moduledoc """
  A prism for bulk deleting messages in a Discord channel.
  """

  use Lux.Prism,
    name: "Bulk Delete Discord Messages",
    description: "Bulk deletes messages in a Discord channel",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string, description: "The ID of the channel", pattern: "^[0-9]{17,20}$"},
        message_ids: %{type: :array, items: %{type: :string}, description: "Message IDs to delete", minItems: 1, maxItems: 100}
      },
      required: ["channel_id", "message_ids"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        success: %{type: :boolean, description: "Whether the bulk delete succeeded"}
      },
      required: ["success"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, channel_id} <- validate_param(params, :channel_id),
         {:ok, message_ids} <- Map.fetch(params, :message_ids) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} bulk deleting #{length(message_ids)} messages from #{channel_id}")

      case Client.request(:post, "/channels/#{channel_id}/messages/bulk-delete", %{json: %{messages: message_ids}}) do
        {:ok, _} -> {:ok, %{success: true}}
        {:error, {status, %{"message" => msg}}} -> {:error, {status, msg}}
        {:error, error} -> {:error, error}
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
