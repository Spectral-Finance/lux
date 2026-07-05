defmodule Lux.Prisms.Discord.Presence.UpdatePresence do
  use Lux.Prism,
    name: "Update Rich Presence",
    description: "Updates the custom status, activity, and game status",
    input_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string, description: "Online status (online, dnd, idle, invisible, offline)", default: "online"},
        activity_type: %{type: :integer, description: "Activity type (0: Game, 1: Streaming, 2: Listening, 3: Watching, 4: Custom, 5: Competing)", default: 0},
        activity_name: %{type: :string, description: "Activity name"},
        state: %{type: :string, description: "Custom status state/details"}
      },
      required: ["activity_name"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        updated: %{type: :boolean}
      },
      required: ["updated"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, _agent) do
    # Presence updates also generally go over Gateway but we'll mock the interface
    Logger.info("Updating presence to #{params.activity_name}")
    {:ok, %{updated: true}}
  end
end
