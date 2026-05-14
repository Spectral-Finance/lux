defmodule Lux.Prisms.Web3.MultiChain.QueryDataset do
  @moduledoc """
  Queries aggregated multi-chain datasets.
  """

  use Lux.Prism,
    name: "Query Multi-Chain Dataset",
    description:
      "Filters aggregated multi-chain data by type, chain, address, topic, limit, and offset",
    input_schema: %{
      type: :object,
      properties: %{
        dataset: %{type: :object, description: "Aggregated multi-chain dataset"},
        type: %{type: :string, description: "Dataset type, such as logs or transactions"},
        chain: %{type: :string, description: "Optional chain slug"},
        address: %{type: :string, description: "Optional contract or wallet address"},
        topic: %{type: :string, description: "Optional event topic"},
        limit: %{type: :integer},
        offset: %{type: :integer}
      },
      required: ["dataset"]
    },
    output_schema: %{type: :object}

  alias Lux.Integrations.Web3.MultiChainAggregation

  @impl true
  def handler(params, _agent) do
    dataset = fetch_param(params, :dataset) || %{}
    opts = Map.drop(params, [:dataset, "dataset"])

    {:ok, MultiChainAggregation.query(dataset, opts)}
  end

  defp fetch_param(params, key) when is_map(params),
    do:
      if(Map.has_key?(params, key),
        do: Map.get(params, key),
        else: Map.get(params, Atom.to_string(key))
      )
end
