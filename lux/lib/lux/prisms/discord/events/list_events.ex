defmodule Lux.Prisms.Discord.Events.ListEvents do
  @moduledoc "A prism for listing scheduled events in a Discord guild."
  use Lux.Prism,
    name: "List Discord Events",
    description: "Lists scheduled events in a Discord guild",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, pattern: "^[0-9]{17,20}$"},
        with_user_count: %{type: :boolean}
      },
      required: ["guild_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        events: %{type: :array},
        guild_id: %{type: :string},
        count: %{type: :integer}
      }
    }
  def handler(input, _ctx) do
    query = if input["with_user_count"], do: "?with_user_count=true", else: ""
    case Lux.Integrations.Discord.Client.request(:get, "/guilds/#{input["guild_id"]}/scheduled-events#{query}") do
      {:ok, events} when is_list(events) -> {:ok, %{events: events, guild_id: input["guild_id"], count: length(events)}}
      {:ok, events} -> {:ok, %{events: events || [], guild_id: input["guild_id"], count: 0}}
      {:error, reason} -> {:error, "List events failed: #{reason}"}
    end
  end
end
