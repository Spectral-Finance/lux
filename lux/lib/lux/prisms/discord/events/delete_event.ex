defmodule Lux.Prisms.Discord.Events.DeleteEvent do
  @moduledoc "A prism for deleting a scheduled event in a Discord guild."
  use Lux.Prism,
    name: "Delete Discord Event",
    description: "Deletes a scheduled event in a Discord guild",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, pattern: "^[0-9]{17,20}$"},
        event_id: %{type: :string, pattern: "^[0-9]{17,20}$"}
      },
      required: ["guild_id", "event_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        deleted: %{type: :boolean},
        event_id: %{type: :string}
      }
    }
  def handler(input, _ctx) do
    case Lux.Integrations.Discord.Client.request(:delete, "/guilds/#{input["guild_id"]}/scheduled-events/#{input["event_id"]}") do
      {:ok, _} -> {:ok, %{deleted: true, event_id: input["event_id"]}}
      {:error, reason} -> {:error, "Event deletion failed: #{reason}"}
    end
  end
end
