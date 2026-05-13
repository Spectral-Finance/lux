defmodule Lux.Prisms.Discord.Events.DeleteScheduledEvent do
  @moduledoc """
  A prism for deleting Discord guild scheduled events.
  """

  use Lux.Prism,
    name: "Delete Discord Scheduled Event",
    description: "Deletes a Discord guild scheduled event",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, pattern: "^[0-9]{17,20}$"},
        event_id: %{type: :string, pattern: "^[0-9]{17,20}$"},
        reason: %{type: :string}
      },
      required: ["guild_id", "event_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        deleted: %{type: :boolean},
        guild_id: %{type: :string},
        event_id: %{type: :string}
      },
      required: ["deleted"]
    }

  alias Lux.Integrations.Discord.Client
  alias Lux.Prisms.Discord.Helpers
  require Logger

  def handler(params, agent) do
    with {:ok, guild_id} <- Helpers.validate_string(params, :guild_id),
         {:ok, event_id} <- Helpers.validate_string(params, :event_id) do
      agent_name = get_in(agent, [:agent, :name]) || agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} deleting scheduled event #{event_id} in guild #{guild_id}")

      case Client.request_with_retry(
             :delete,
             "/guilds/#{guild_id}/scheduled-events/#{event_id}",
             Helpers.client_opts(params)
           ) do
        {:ok, _} ->
          {:ok, %{deleted: true, guild_id: guild_id, event_id: event_id}}

        error ->
          Logger.error("Failed to delete Discord scheduled event #{event_id}: #{inspect(error)}")
          error
      end
    end
  end
end
