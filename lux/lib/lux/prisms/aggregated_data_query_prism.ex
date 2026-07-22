defmodule Lux.Prisms.AggregatedDataQueryPrism do
  @moduledoc """
  A prism for querying historical cross-chain EVM data (blocks, transactions, event logs).
  """
  use Lux.Prism,
    name: "Aggregated Data Query",
    description: "Executes historical queries across multi-chain EVM data",
    input_schema: %{
      type: :object,
      properties: %{
        chains: %{
          type: :array,
          description: "List of chain identifiers (e.g., ['ethereum', 'polygon', 'bsc', 'arbitrum'])",
          items: %{type: :string},
          default: ["ethereum"]
        },
        type: %{
          type: :string,
          description: "Data type to query ('block', 'transaction', 'log')",
          default: "block"
        },
        from_block: %{
          type: [:integer, :string],
          description: "Starting block number"
        },
        to_block: %{
          type: [:integer, :string],
          description: "Ending block number"
        },
        address: %{
          type: :string,
          description: "Address filter (contract address, sender, or receiver)"
        },
        topic: %{
          type: :string,
          description: "Topic 0 filter for event logs"
        },
        limit: %{
          type: :integer,
          description: "Maximum number of records to return"
        }
      },
      required: ["type"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        results: %{
          type: :array,
          description: "List of matching normalized records"
        },
        count: %{
          type: :integer,
          description: "Number of records returned"
        },
        chains: %{
          type: :array,
          description: "List of queried chains",
          items: %{type: :string}
        }
      },
      required: ["results", "count", "chains"]
    }

  alias Lux.Web3.DataNormalizer
  alias Lux.Web3.StorageEngine

  def handler(input, _ctx) do
    raw_chains = fetch_param(input, [:chains, "chains"]) || ["ethereum"]

    chains =
      cond do
        is_list(raw_chains) -> Enum.map(raw_chains, &DataNormalizer.normalize_chain/1)
        is_binary(raw_chains) -> [DataNormalizer.normalize_chain(raw_chains)]
        true -> ["ethereum"]
      end

    type = fetch_param(input, [:type, "type"]) || "block"
    from_block = DataNormalizer.parse_hex_or_int(fetch_param(input, [:from_block, "from_block", :fromBlock, "fromBlock"]))
    to_block = DataNormalizer.parse_hex_or_int(fetch_param(input, [:to_block, "to_block", :toBlock, "toBlock"]))
    address = fetch_param(input, [:address, "address"])
    topic = fetch_param(input, [:topic, "topic"])
    limit = fetch_param(input, [:limit, "limit"])

    results =
      Enum.flat_map(chains, fn chain ->
        query_opts = [
          chain: chain,
          type: type,
          from_block: from_block,
          to_block: to_block,
          address: address,
          topic: topic
        ]

        case StorageEngine.query(query_opts) do
          {:ok, items} -> items
          _ -> []
        end
      end)

    limited_results =
      if is_integer(limit) and limit > 0 do
        Enum.take(results, limit)
      else
        results
      end

    {:ok, %{results: limited_results, count: length(limited_results), chains: chains}}
  end

  defp fetch_param(map, keys) when is_map(map) do
    Enum.find_value(keys, fn key -> Map.get(map, key) end)
  end
  defp fetch_param(_, _), do: nil
end
