defmodule Lux.Prisms.Discord.EventHandlingPrism do
  use Lux.Prism,
    name: "Discord Event Handling",
    description: "Schedule Discord Server Events",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, enum: ["schedule_event"]},
        guild_id: %{type: :string},
        name: %{type: :string},
        start_time: %{type: :string},
        end_time: %{type: :string},
        description: %{type: :string},
        location: %{type: :string}
      },
      required: ["action", "guild_id", "name", "start_time"]
    }

  alias Lux.Utils.DiscordApi

  def handler(%{"action" => "schedule_event", "guild_id" => guild_id, "name" => name, "start_time" => start_time} = input, _ctx) do
    # Verify ISO8601 parsing by just trying to parse it
    case DateTime.from_iso8601(start_time) do
      {:ok, _, _} ->
        payload = %{
          name: name,
          scheduled_start_time: start_time,
          privacy_level: 2, # GUILD_ONLY
          entity_type: 3 # EXTERNAL by default for this example if location provided, else voice channel
        }
        
        payload = if desc = Map.get(input, "description"), do: Map.put(payload, :description, desc), else: payload
        
        payload = 
          if loc = Map.get(input, "location") do
            payload
            |> Map.put(:entity_metadata, %{location: loc})
            |> Map.put(:entity_type, 3) # EXTERNAL
          else
            # 2 is VOICE, but requires channel_id. Let's just use EXTERNAL with a default location if not provided.
            payload
            |> Map.put(:entity_metadata, %{location: "TBD"})
            |> Map.put(:entity_type, 3)
          end
          
        payload = 
          if et = Map.get(input, "end_time") do
            case DateTime.from_iso8601(et) do
              {:ok, _, _} -> Map.put(payload, :scheduled_end_time, et)
              _ -> payload
            end
          else
            # For EXTERNAL, end_time is required. Let's add 1 hour by default.
            case DateTime.from_iso8601(start_time) do
              {:ok, dt, _} -> Map.put(payload, :scheduled_end_time, DateTime.add(dt, 3600, :second) |> DateTime.to_iso8601())
              _ -> payload
            end
          end

        DiscordApi.request(:post, "/guilds/#{guild_id}/scheduled-events", payload)

      _ ->
        {:error, "invalid start_time format, expected ISO8601"}
    end
  end

  def handler(%{"action" => "schedule_event"}, _ctx), do: {:error, "guild_id, name, and start_time are required for schedule_event"}
  
  def handler(_, _), do: {:error, "Invalid action or missing required parameters"}
end
