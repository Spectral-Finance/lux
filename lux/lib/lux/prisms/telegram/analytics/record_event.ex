defmodule Lux.Prisms.Telegram.Analytics.RecordEvent do
  @moduledoc """
  Records a normalized Telegram analytics event into an event list.
  """

  use Lux.Prism,
    name: "Record Telegram Analytics Event",
    description: "Normalizes and prepends a Telegram bot analytics event to an event list",
    input_schema: %{
      type: :object,
      properties: %{
        events: %{type: :array, description: "Existing analytics events"},
        event: %{type: :object, description: "New Telegram analytics event"}
      },
      required: ["event"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        events: %{type: :array}
      },
      required: ["events"]
    }

  alias Lux.Integrations.Telegram.Analytics

  @impl true
  def handler(params, _ctx) do
    events = Map.get(params, :events, Map.get(params, "events", []))
    event = Map.get(params, :event, Map.get(params, "event"))

    with {:ok, events} <- Analytics.record_event(events, event) do
      {:ok, %{events: events}}
    end
  end
end
