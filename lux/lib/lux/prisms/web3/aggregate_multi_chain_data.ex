defmodule Lux.Prisms.Web3.AggregateMultiChainData do
  @moduledoc """
  Builds a normalized multi-chain data snapshot for agent workflows.
  """

  use Lux.Prism,
    name: "Aggregate Multi-Chain Data",
    description:
      "Normalizes multi-chain block, transaction, and event data into a queryable snapshot",
    input_schema: %{
      type: :object,
      properties: %{
        chains: %{type: :array, description: "EVM chain definitions"},
        blocks: %{type: :array, description: "Block records"},
        transactions: %{type: :array, description: "Transaction records"},
        events: %{type: :array, description: "Contract event records"}
      },
      required: ["chains"]
    },
    output_schema: %{
      type: :object,
      properties: %{snapshot: %{type: :object}, stream_payload: %{type: :object}},
      required: ["snapshot"]
    }

  alias Lux.Web3.MultiChain.Aggregator

  @impl true
  def handler(params, _ctx) do
    with {:ok, snapshot} <- Aggregator.snapshot(params) do
      {:ok, %{snapshot: snapshot, stream_payload: Aggregator.stream_payload(snapshot)}}
    end
  end
end
