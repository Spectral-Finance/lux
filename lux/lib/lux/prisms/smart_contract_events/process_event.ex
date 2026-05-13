defmodule Lux.Prisms.SmartContractEvents.ProcessEvent do
  @moduledoc """
  Processes one raw smart contract event through active monitor subscriptions.
  """

  use Lux.Prism,
    name: "Process Smart Contract Event",
    description: "Filters, decodes, stores, and optionally webhooks one raw contract log.",
    input_schema: %{
      type: :object,
      properties: %{
        event: %{type: :object, description: "Raw log/event payload"},
        notify: %{type: :boolean, description: "Whether webhook notifications should be sent"}
      },
      required: ["event"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        matched: %{type: :integer},
        stored: %{type: :integer},
        events: %{type: :array}
      },
      required: ["matched", "stored", "events"]
    }

  def handler(input, _context) do
    event = Map.get(input, :event) || Map.get(input, "event")
    notify = Map.get(input, :notify, Map.get(input, "notify", true))

    Lux.EventMonitor.process_event(event, notify: notify)
  end
end
