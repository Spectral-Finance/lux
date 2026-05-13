defmodule Lux.Prisms.Discord.Messages.BulkDeleteMessages do
  @moduledoc """
  A prism for bulk-deleting Discord messages from a channel.

  Discord accepts 2 to 100 message IDs per bulk-delete request. This prism keeps
  the request shape close to Discord's API and uses the retry-aware Discord
  client for transient 429/5xx responses.
  """

  use Lux.Prism,
    name: "Bulk Delete Discord Messages",
    description: "Deletes 2 to 100 messages from a Discord channel",
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
          description: "Discord message IDs to delete",
          items: %{type: :string, pattern: "^[0-9]{17,20}$"},
          minItems: 2,
          maxItems: 100
        },
        reason: %{
          type: :string,
          description: "Optional Discord audit-log reason"
        }
      },
      required: ["channel_id", "message_ids"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        deleted: %{type: :boolean},
        deleted_count: %{type: :integer},
        channel_id: %{type: :string}
      },
      required: ["deleted", "deleted_count"]
    }

  alias Lux.Integrations.Discord.Client
  alias Lux.Prisms.Discord.Helpers
  require Logger

  def handler(params, agent) do
    with {:ok, channel_id} <- Helpers.validate_string(params, :channel_id),
         {:ok, message_ids} <- Helpers.validate_string_list(params, :message_ids, min: 2, max: 100) do
      agent_name = get_in(agent, [:agent, :name]) || agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} bulk deleting #{length(message_ids)} messages in #{channel_id}")

      opts = Helpers.client_opts(params, %{json: %{messages: message_ids}})

      case Client.request_with_retry(:post, "/channels/#{channel_id}/messages/bulk-delete", opts) do
        {:ok, _} ->
          {:ok, %{deleted: true, deleted_count: length(message_ids), channel_id: channel_id}}

        error ->
          Logger.error("Failed to bulk delete messages in #{channel_id}: #{inspect(error)}")
          error
      end
    end
  end
end
