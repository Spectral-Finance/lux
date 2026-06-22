defmodule Lux.Prisms.Web3.MultiChain.QueryEvents do
  @moduledoc """
  A Prism for querying aggregated events across chains.
  """
  use Lux.Prism

  alias Lux.Integrations.Web3.MultiChain.Aggregator

  def handler(params, _context) do
    chain_id = Map.get(params, :chain_id)
    events = Aggregator.query_events(chain_id)
    {:ok, %{status: "success", count: length(events), data: events}}
  end
end
