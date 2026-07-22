defmodule Lux.Prisms.IndexerPrism do
  @moduledoc """
  Indexes events or logs from a specific chain and contract.
  """
  use Lux.Prism,
    name: "Blockchain Indexer",
    description: "Indexes events and logs from a specific chain and contract",
    input_schema: %{
      type: :object,
      properties: %{
        chain: %{
          type: :string,
          description: "Chain identifier (e.g., ethereum, polygon)"
        },
        contract_address: %{
          type: :string,
          description: "Contract address to index"
        },
        from_block: %{
          type: :string,
          description: "Starting block number in hex or \"latest\", \"earliest\"",
          default: "latest"
        },
        to_block: %{
          type: :string,
          description: "Ending block number in hex or \"latest\"",
          default: "latest"
        },
        topics: %{
          type: :array,
          description: "Array of topics to filter",
          default: []
        }
      },
      required: ["chain", "contract_address"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        logs: %{
          type: :array,
          description: "Indexed logs"
        }
      },
      required: ["logs"]
    }

  def handler(input, ctx) do
    with {:ok, chain} <- fetch_param(input, :chain),
         {:ok, contract_address} <- fetch_param(input, :contract_address) do
      from_block = get_param(input, :from_block, "latest")
      to_block = get_param(input, :to_block, "latest")
      topics = get_param(input, :topics, [])

      filter = %{address: contract_address, fromBlock: from_block, toBlock: to_block}
      filter = if Enum.empty?(topics), do: filter, else: Map.put(filter, :topics, topics)

      Lux.Prisms.MultiChainRpcPrism.handler(%{chain: chain, method: "eth_getLogs", params: [filter]}, ctx)
      |> case do
        {:ok, %{result: logs}} when is_list(logs) -> {:ok, %{logs: logs}}
        {:ok, %{result: nil}} -> {:ok, %{logs: []}}
        {:error, error} -> {:error, "Failed to index logs: #{error}"}
      end
    end
  end

  defp fetch_param(params, key) do
    string_key = Atom.to_string(key)

    cond do
      Map.has_key?(params, key) -> {:ok, Map.fetch!(params, key)}
      Map.has_key?(params, string_key) -> {:ok, Map.fetch!(params, string_key)}
      true -> {:error, "#{string_key} is required"}
    end
  end

  defp get_param(params, key, default \\ nil) do
    case fetch_param(params, key) do
      {:ok, value} -> value
      {:error, _} -> default
    end
  end
end
