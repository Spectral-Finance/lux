defmodule Lux.Prisms.Web3.MultiChain.BuildRequestPlan do
  @moduledoc """
  Builds JSON-RPC request plans for multiple EVM chains.
  """

  use Lux.Prism,
    name: "Build Multi-Chain RPC Request Plan",
    description:
      "Builds chain-aware JSON-RPC request payloads for latest blocks, logs, balances, and transaction counts",
    input_schema: %{
      type: :object,
      properties: %{
        chains: %{type: :array, description: "Chain slugs or chain metadata maps"},
        actions: %{type: :array, description: "RPC action names"},
        filter: %{type: :object, description: "Event or address filter"}
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        chains: %{type: :object},
        requests: %{type: :array},
        summary: %{type: :object}
      },
      required: ["chains", "requests", "summary"]
    }

  alias Lux.Integrations.Web3.MultiChainAggregation

  @impl true
  def handler(params, _agent) do
    chains = fetch_param(params, :chains) || []
    opts = Map.take(params, [:actions, :filter, :request_id_start, :rate_limit])

    {:ok, MultiChainAggregation.plan_requests(chains, opts)}
  end

  defp fetch_param(params, key) when is_map(params),
    do:
      if(Map.has_key?(params, key),
        do: Map.get(params, key),
        else: Map.get(params, Atom.to_string(key))
      )
end
