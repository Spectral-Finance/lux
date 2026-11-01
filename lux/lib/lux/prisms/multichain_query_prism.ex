defmodule Lux.Prisms.MultichainQueryPrism do
  @moduledoc """
  Lux Prism for executing queries on normalized multi-chain EVM data (#74).

  Allows AI agents and workflows to query blocks, transactions, and event logs
  across Ethereum, BSC, Polygon, Arbitrum, Optimism, Base, and Avalanche.
  """

  use Lux.Prism,
    name: "Multi-Chain Query Prism",
    description: "Queries normalized multi-chain EVM blockchain blocks, transactions, and events",
    input_schema: %{
      type: :object,
      properties: %{
        query_type: %{
          type: :string,
          enum: ["blocks", "transactions", "events"],
          description: "Entity type to query"
        },
        chain: %{
          type: :string,
          description: "Target chain (ethereum, bsc, polygon, arbitrum, optimism, base, avalanche)"
        },
        from_block: %{
          type: :integer,
          description: "Starting block number"
        },
        to_block: %{
          type: :integer,
          description: "Ending block number"
        },
        contract_address: %{
          type: :string,
          description: "Smart contract address filter for events"
        },
        limit: %{
          type: :integer,
          description: "Maximum number of records to return",
          default: 20
        }
      },
      required: ["query_type"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        count: %{type: :integer},
        query_type: %{type: :string},
        results: %{type: :array}
      },
      required: ["count", "query_type", "results"]
    }

  alias Lux.Web3.Multichain.Aggregator

  def handler(input, _context) do
    query_type = Map.get(input, :query_type) || Map.get(input, "query_type")
    chain_str = Map.get(input, :chain) || Map.get(input, "chain")
    chain = if chain_str, do: String.to_existing_atom(chain_str), else: nil
    limit = Map.get(input, :limit) || Map.get(input, "limit") || 20
    from_b = Map.get(input, :from_block) || Map.get(input, "from_block")
    to_b = Map.get(input, :to_block) || Map.get(input, "to_block")
    contract = Map.get(input, :contract_address) || Map.get(input, "contract_address")

    filter =
      %{}
      |> maybe_put(:chain, chain)
      |> maybe_put(:limit, limit)
      |> maybe_put(:from_block, from_b)
      |> maybe_put(:to_block, to_b)
      |> maybe_put(:contract_address, contract)

    results =
      case query_type do
        "blocks" ->
          Aggregator.query_blocks(Aggregator, filter)

        "transactions" ->
          Aggregator.query_transactions(Aggregator, filter)

        "events" ->
          Aggregator.query_events(Aggregator, filter)

        _ ->
          []
      end

    {:ok,
     %{
       count: length(results),
       query_type: query_type,
       results: results
     }}
  rescue
    e ->
      {:error, Exception.message(e)}
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)
end
