defmodule Lux.Prisms.Discord.Advanced.RichPresencePrism do
  @moduledoc """
  A prism that manages Discord Rich Presence status, activities, and game state.
  """

  use Lux.Prism,
    name: "Discord Rich Presence Prism",
    description: "Updates bot presence, activity states, and game status synchronization",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: ["update_presence", "sync_game", "custom_status", "get_presence"],
          default: "get_presence"
        },
        status: %{
          type: :string,
          enum: ["online", "dnd", "idle", "invisible"],
          default: "online"
        },
        activity_name: %{type: :string},
        activity_type: %{
          type: :string,
          enum: ["game", "streaming", "listening", "watching", "competing"],
          default: "game"
        },
        details: %{type: :string},
        state: %{type: :string},
        text: %{type: :string}
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string},
        presence: %{type: :object},
        status: %{type: :string}
      },
      required: ["action", "presence", "status"]
    }

  alias Lux.Discord.Presence

  @impl true
  def handler(inputs, _context) do
    action = Map.get(inputs, "action") || Map.get(inputs, :action, "get_presence")

    case action do
      "update_presence" ->
        status_atom = String.to_atom(Map.get(inputs, "status") || Map.get(inputs, :status, "online"))
        act_name = Map.get(inputs, "activity_name") || Map.get(inputs, :activity_name, "Autonomous Agent")
        act_type_atom = String.to_atom(Map.get(inputs, "activity_type") || Map.get(inputs, :activity_type, "game"))
        details = Map.get(inputs, "details") || Map.get(inputs, :details)
        state = Map.get(inputs, "state") || Map.get(inputs, :state)

        {:ok, presence} =
          Presence.update_presence(%{
            status: status_atom,
            activity_name: act_name,
            activity_type: act_type_atom,
            details: details,
            state: state
          })

        {:ok, %{action: "update_presence", presence: presence, status: "updated"}}

      "sync_game" ->
        title = Map.get(inputs, "activity_name") || Map.get(inputs, :activity_name, "Lux Sim")
        details = Map.get(inputs, "details") || Map.get(inputs, :details, "Managing Agents")
        state = Map.get(inputs, "state") || Map.get(inputs, :state, "Level 42")

        {:ok, presence} = Presence.sync_game_status(title, details, state)
        {:ok, %{action: "sync_game", presence: presence, status: "synchronized"}}

      "custom_status" ->
        text = Map.get(inputs, "text") || Map.get(inputs, :text, "Building the agent economy 🚀")
        {:ok, presence} = Presence.set_custom_status(text)
        {:ok, %{action: "custom_status", presence: presence, status: "updated"}}

      _get_presence ->
        presence = Presence.get_presence()
        {:ok, %{action: "get_presence", presence: presence, status: "ok"}}
    end
  end
end
