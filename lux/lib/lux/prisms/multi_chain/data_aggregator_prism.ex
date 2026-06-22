defmodule Lux.Prisms.MultiChain.DataAggregatorPrism do
  @moduledoc """
  Aggregates data (blocks, transactions, events) from multiple EVM-compatible chains.
  """
  use Lux.Prism,
    name: "Multi-Chain Data Aggregator",
    description: "Aggregates block, transaction, or event data across multiple EVM chains",
    input_schema: %{
      type: :object,
      properties: %{
        chains: %{
          type: :array,
          items: %{type: :string},
          description: "List of chains to query (e.g., ['ethereum', 'polygon', 'bsc'])",
          default: ["ethereum", "polygon"]
        },
        data_type: %{
          type: :string,
          enum: ["block", "transaction", "event"],
          description: "Type of data to aggregate",
          default: "block"
        },
        block_number: %{
          type: :string,
          description: "Block number or 'latest'"
        },
        contract_address: %{
          type: :string,
          description: "Contract address for event aggregation"
        }
      },
      required: ["chains", "data_type"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        aggregated_data: %{
          type: :object,
          description: "Data aggregated by chain"
        },
        errors: %{
          type: :object,
          description: "Any errors encountered per chain"
        }
      },
      required: ["aggregated_data"]
    }

  import Lux.Python
  alias Lux.Config
  require Lux.Python

  def handler(input, _ctx) do
    chains = Map.get(input, :chains, ["ethereum", "polygon"])
    data_type = Map.get(input, :data_type, "block")
    block_number = Map.get(input, :block_number, "latest")
    contract_address = Map.get(input, :contract_address, nil)
    
    with {:ok, %{"success" => true}} <- Lux.Python.import_package("web3"),
         {:ok, result} <- aggregate_data(chains, data_type, block_number, contract_address) do
      {:ok, atomize_keys(result)}
    else
      {:ok, %{"success" => false, "error" => error}} ->
        {:error, "Failed to import Web3: #{error}"}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp aggregate_data(chains, data_type, block_number, contract_address) do
    api_key = Config.alchemy_api_key() || ""
    
    result =
      python variables: %{
        chains: chains, 
        data_type: data_type, 
        block_number: block_number, 
        contract_address: contract_address, 
        api_key: api_key
      } do
        ~PY"""
        def aggregate_multi_chain(chains, data_type, block_number, contract_address, api_key):
            from web3 import Web3
            import json

            NETWORKS = {
                "ethereum": f"https://eth-mainnet.g.alchemy.com/v2/{api_key}" if api_key else "https://cloudflare-eth.com",
                "polygon": f"https://polygon-mainnet.g.alchemy.com/v2/{api_key}" if api_key else "https://polygon-rpc.com",
                "bsc": "https://bsc-dataseed.binance.org/",
                "avalanche": "https://api.avax.network/ext/bc/C/rpc",
                "arbitrum": f"https://arb-mainnet.g.alchemy.com/v2/{api_key}" if api_key else "https://arb1.arbitrum.io/rpc"
            }

            aggregated_data = {}
            errors = {}

            for chain in chains:
                if chain not in NETWORKS:
                    errors[chain] = f"Unsupported chain: {chain}"
                    continue
                
                try:
                    w3 = Web3(Web3.HTTPProvider(NETWORKS[chain]))
                    
                    if not w3.is_connected():
                        errors[chain] = "Failed to connect to RPC"
                        continue

                    if data_type == "block":
                        block = w3.eth.get_block(block_number if block_number != "latest" else "latest")
                        aggregated_data[chain] = {
                            "number": block.number,
                            "timestamp": block.timestamp,
                            "hash": block.hash.hex() if block.hash else None,
                            "transactions_count": len(block.transactions)
                        }
                    elif data_type == "transaction":
                        block = w3.eth.get_block("latest", full_transactions=True)
                        txs = []
                        for tx in block.transactions[:5]:
                            txs.append({
                                "hash": tx.hash.hex(),
                                "from": tx['from'],
                                "to": tx.to,
                                "value": str(tx.value)
                            })
                        aggregated_data[chain] = txs
                    elif data_type == "event":
                        if not contract_address:
                            errors[chain] = "Contract address required for event aggregation"
                            continue
                        
                        logs = w3.eth.get_logs({
                            "address": w3.to_checksum_address(contract_address),
                            "fromBlock": "latest",
                            "toBlock": "latest"
                        })
                        processed_logs = []
                        for log in logs[:10]:
                            processed_logs.append({
                                "transactionHash": log.transactionHash.hex(),
                                "blockNumber": log.blockNumber,
                                "data": log.data.hex() if hasattr(log.data, 'hex') else str(log.data)
                            })
                        aggregated_data[chain] = processed_logs
                except Exception as e:
                    errors[chain] = str(e)
            
            return {
                "aggregated_data": aggregated_data,
                "errors": errors
            }

        result = aggregate_multi_chain(chains, data_type, block_number, contract_address, api_key)
        result
        """
      end

    if Map.has_key?(result, "error") do
      {:error, result["error"]}
    else
      {:ok, result}
    end
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_map(v) -> {String.to_atom(k), atomize_keys(v)}
      {k, v} -> {String.to_atom(k), v}
    end)
  end
  defp atomize_keys(other), do: other
end
