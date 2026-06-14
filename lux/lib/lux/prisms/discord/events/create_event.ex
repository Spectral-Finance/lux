defmodule Lux.Prisms.Discord.Events.CreateEvent do
  @moduledoc "A prism for creating a scheduled event in a Discord guild."
  use Lux.Prism,
    name: "Create Discord Event",
    description: "Creates a scheduled event in a Discord guild",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, pattern: "^[0-9]{17,20}$"},
        name: %{type: :string, minLength: 1, maxLength: 100},
        description: %{type: :string, maxLength: 1000},
        scheduled_start_time: %{type: :string, description: "ISO 8601 start time"},
        scheduled_end_time: %{type: :string, description: "ISO 8601 end time"},
        entity_type: %{type: :integer, enum: [2, 3, 8], description: "2: stage, 3: voice, 8: external"},
        channel_id: %{type: :string, pattern: "^[0-9]{17,20}$"},
        location: %{type: :string, maxLength: 100}
      },
      required: ["guild_id", "name", "scheduled_start_time", "entity_type"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        created: %{type: :boolean},
        event_id: %{type: :string},
        name: %{type: :string}
      }
    }
  def handler(input, _ctx) do
    body = %{name: input["name"], scheduled_start_time: input["scheduled_start_time"], entity_type: input["entity_type"]}
    body = if input["description"], do: Map.put(body, :description, input["description"]), else: body
    body = if input["scheduled_end_time"], do: Map.put(body, :scheduled_end_time, input["scheduled_end_time"]), else: body
    body = if input["channel_id"], do: Map.put(body, :channel_id, input["channel_id"]), else: body
    body = if input["location"], do: Map.put(body, :location, input["location"]), else: body
    case Lux.Integrations.Discord.Client.request(:post, "/guilds/#{input["guild_id"]}/scheduled-events", json: body) do
      {:ok, ev} -> {:ok, %{created: true, event_id: ev["id"], name: ev["name"]}}
      {:error, reason} -> {:error, "Event creation failed: #{reason}"}
    end
  end
end
