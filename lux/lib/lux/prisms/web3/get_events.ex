defmodule Lux.Prisms.Web3.GetEvents do
  @moduledoc """
  A prism to query the currently stored Web3 events from the EventMonitor storage.
  """
  use Lux.Prism,
    name: "Web3 Get Stored Events",
    description: "Retrieves smart contract events from local event monitor storage.",
    input_schema: %{
      type: :object,
      properties: %{
        address: %{
          type: :string,
          description: "Optional contract address to filter by."
        },
        topic: %{
          type: :string,
          description: "Optional topic string to filter by."
        }
      }
    }

  alias Lux.Integrations.Web3.EventMonitor

  def handler(params, _context) do
    opts = [
      address: Map.get(params, :address),
      topic: Map.get(params, :topic)
    ]
    
    # Prune nil options
    opts = Enum.reject(opts, fn {_k, v} -> is_nil(v) end)

    events = EventMonitor.query_events(opts)
    {:ok, events}
  end
end
