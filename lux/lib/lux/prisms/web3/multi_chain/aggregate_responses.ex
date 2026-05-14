defmodule Lux.Prisms.Web3.MultiChain.AggregateResponses do
  @moduledoc """
  Aggregates multi-chain JSON-RPC response envelopes.
  """

  use Lux.Prism,
    name: "Aggregate Multi-Chain Responses",
    description:
      "Normalizes JSON-RPC responses into latest block, log, transaction, health, performance, and retention summaries",
    input_schema: %{
      type: :object,
      properties: %{
        responses: %{type: :array, description: "Collected JSON-RPC response envelopes"},
        generated_at: %{type: :string, description: "Optional report timestamp"},
        retention: %{type: :object, description: "Retention policy overrides"}
      },
      required: ["responses"]
    },
    output_schema: %{type: :object}

  alias Lux.Integrations.Web3.MultiChainAggregation

  @impl true
  def handler(params, _agent) do
    responses = fetch_param(params, :responses) || []
    opts = Map.take(params, [:generated_at, :retention])

    {:ok, MultiChainAggregation.aggregate_responses(responses, opts)}
  end

  defp fetch_param(params, key) when is_map(params),
    do:
      if(Map.has_key?(params, key),
        do: Map.get(params, key),
        else: Map.get(params, Atom.to_string(key))
      )
end
