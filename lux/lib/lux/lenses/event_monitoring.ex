defmodule Lux.Lenses.EventMonitoring do
  @moduledoc """
  Lens for querying the event monitoring dashboard.

  Provides a unified interface for retrieving event statistics,
  recent events, and contract summaries through the Lens system.
  """

  use Lux.Lens,
    name: "EventMonitoring",
    description: "Query the smart contract event monitoring system for dashboards and analytics",
    url: "internal://event-monitoring",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "Query type",
          enum: ["snapshot", "recent", "contract_summary", "contract_events", "event_types", "event_frequency"]
        },
        contract: %{type: :string, description: "Contract address"},
        limit: %{type: :integer, description: "Number of events", default: 20},
        from_block: %{type: :integer, description: "Starting block"},
        to_block: %{type: :integer, description: "Ending block"}
      },
      required: ["action"]
    }

  def after_focus(%{"action" => "snapshot"} = params) do
    limit = Map.get(params, "limit", 20)
    Lux.Web3.Events.Dashboard.query(:snapshot, limit)
  end

  def after_focus(%{"action" => "recent"} = params) do
    limit = Map.get(params, "limit", 20)
    Lux.Web3.Events.Dashboard.query(:recent, limit)
  end

  def after_focus(%{"action" => "contract_summary"} = _params) do
    Lux.Web3.Events.Dashboard.query(:contract_summary)
  end

  def after_focus(%{"action" => "contract_events"} = params) do
    contract = Map.get(params, "contract", "")
    limit = Map.get(params, "limit", 100)
    from = Map.get(params, "from_block")
    to = Map.get(params, "to_block")
    Lux.Web3.Events.Dashboard.query(:contract_events, %{contract: contract, limit: limit, from_block: from, to_block: to})
  end

  def after_focus(%{"action" => "event_types"} = params) do
    contract = Map.get(params, "contract", "")
    Lux.Web3.Events.Dashboard.query(:event_types, contract)
  end

  def after_focus(%{"action" => "event_frequency"} = params) do
    contract = Map.get(params, "contract", "")
    from = Map.get(params, "from_block", 0)
    to = Map.get(params, "to_block", 0)
    bucket = Map.get(params, "bucket_size", 100)
    Lux.Web3.Events.Dashboard.query(:event_frequency, %{contract: contract, from_block: from, to_block: to, bucket_size: bucket})
  end

  def after_focus(params) do
    {:error, "Unknown action: #{inspect(params["action"])}"}
  end
end
