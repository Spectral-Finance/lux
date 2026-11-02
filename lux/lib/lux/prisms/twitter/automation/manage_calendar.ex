defmodule Lux.Prisms.Twitter.Automation.ManageCalendar do
  @moduledoc """
  A prism for managing content calendar slots and planning schedule batches.
  """

  use Lux.Prism,
    name: "Manage Twitter Content Calendar",
    description: "Configures recurring content slots and plans automated scheduling for draft tweets",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, description: "'add_slot', 'get_upcoming', or 'plan_schedule'"},
        day_of_week: %{type: :integer, description: "1 (Mon) to 7 (Sun)"},
        time: %{type: :string, description: "'HH:MM' e.g. '09:00'"},
        topic: %{type: :string, description: "Topic theme atom/string"},
        drafts: %{type: :array, description: "List of draft maps for 'plan_schedule'"}
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        result: %{type: :array}
      },
      required: ["status"]
    }

  alias Lux.Integrations.Twitter.Automation.ContentCalendar

  def handler(params, _agent) when is_map(params) do
    action = to_string(Map.get(params, :action) || Map.get(params, "action", "get_upcoming"))
    calendar = ContentCalendar.new_calendar()

    case action do
      "add_slot" ->
        dow = Map.get(params, :day_of_week) || Map.get(params, "day_of_week", 1)
        time_str = Map.get(params, :time) || Map.get(params, "time", "12:00")
        topic = String.to_atom(to_string(Map.get(params, :topic) || Map.get(params, "topic", "general")))

        with {:ok, _cal, slot} <- ContentCalendar.add_slot(calendar, dow, time_str, topic) do
          {:ok, %{status: "slot_added", result: [slot]}}
        end

      "plan_schedule" ->
        drafts = Map.get(params, :drafts) || Map.get(params, "drafts", [])
        # Add default slots if calendar is empty
        {:ok, cal, _} = ContentCalendar.add_slot(calendar, 1, "09:00", :market_update)
        {:ok, cal, _} = ContentCalendar.add_slot(cal, 3, "14:00", :education)
        {:ok, cal, _} = ContentCalendar.add_slot(cal, 5, "17:00", :community)

        plan = ContentCalendar.plan_schedule(cal, drafts)
        {:ok, %{status: "planned", result: plan}}

      _ ->
        {:ok, cal, _} = ContentCalendar.add_slot(calendar, 1, "09:00", :general)
        upcoming = ContentCalendar.get_upcoming_slots(cal)
        {:ok, %{status: "ok", result: upcoming}}
    end
  end

  def handler(_, _), do: {:error, "Invalid parameters"}
end
