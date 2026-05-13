defmodule Lux.Prisms.Discord.Events.CreateScheduledEvent do
  @moduledoc """
  A prism for creating Discord guild scheduled events.

  Supports both channel-backed events and external events. For external events,
  pass `entity_type: 3`, `scheduled_end_time`, and `location`.
  """

  use Lux.Prism,
    name: "Create Discord Scheduled Event",
    description: "Creates a Discord guild scheduled event",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, pattern: "^[0-9]{17,20}$"},
        name: %{type: :string, minLength: 1, maxLength: 100},
        scheduled_start_time: %{type: :string, description: "ISO-8601 start time"},
        scheduled_end_time: %{type: :string, description: "ISO-8601 end time for external events"},
        privacy_level: %{type: :integer, enum: [2], default: 2},
        entity_type: %{type: :integer, enum: [1, 2, 3], default: 3},
        channel_id: %{type: :string, pattern: "^[0-9]{17,20}$"},
        location: %{type: :string, description: "Location for external events"},
        description: %{type: :string, maxLength: 1000},
        reason: %{type: :string}
      },
      required: ["guild_id", "name", "scheduled_start_time"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        created: %{type: :boolean},
        guild_id: %{type: :string},
        event_id: %{type: :string},
        name: %{type: :string}
      },
      required: ["created", "event_id"]
    }

  alias Lux.Integrations.Discord.Client
  alias Lux.Prisms.Discord.Helpers
  require Logger

  def handler(params, agent) do
    with {:ok, guild_id} <- Helpers.validate_string(params, :guild_id),
         {:ok, name} <- Helpers.validate_string(params, :name),
         {:ok, start_time} <- Helpers.validate_string(params, :scheduled_start_time),
         {:ok, payload} <- build_payload(params, name, start_time) do
      agent_name = get_in(agent, [:agent, :name]) || agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} creating scheduled event #{name} in guild #{guild_id}")

      opts = Helpers.client_opts(params, %{json: payload})

      case Client.request_with_retry(:post, "/guilds/#{guild_id}/scheduled-events", opts) do
        {:ok, %{"id" => event_id} = response} ->
          {:ok,
           %{
             created: true,
             guild_id: guild_id,
             event_id: event_id,
             name: Map.get(response, "name", name)
           }}

        error ->
          Logger.error("Failed to create Discord scheduled event in #{guild_id}: #{inspect(error)}")
          error
      end
    end
  end

  defp build_payload(params, name, start_time) do
    entity_type = Map.get(params, :entity_type, Map.get(params, "entity_type", 3))
    privacy_level = Map.get(params, :privacy_level, Map.get(params, "privacy_level", 2))

    payload =
      %{
        name: name,
        scheduled_start_time: start_time,
        privacy_level: privacy_level,
        entity_type: entity_type
      }
      |> maybe_put(:scheduled_end_time, Map.get(params, :scheduled_end_time, Map.get(params, "scheduled_end_time")))
      |> maybe_put(:channel_id, Map.get(params, :channel_id, Map.get(params, "channel_id")))
      |> maybe_put(:description, Map.get(params, :description, Map.get(params, "description")))
      |> maybe_put_external_location(entity_type, Map.get(params, :location, Map.get(params, "location")))

    {:ok, payload}
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_external_location(map, 3, location) when is_binary(location) and location != "" do
    Map.put(map, :entity_metadata, %{location: location})
  end

  defp maybe_put_external_location(map, _entity_type, _location), do: map
end
