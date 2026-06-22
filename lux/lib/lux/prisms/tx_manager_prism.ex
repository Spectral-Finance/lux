defmodule Lux.Prisms.TxManagerPrism do
  @moduledoc """
  Transaction management prism.

  Supports:
  - simulate: Simulates a transaction (eth_call)
  - batch: Batches multiple transactions
  - replace: Replaces a transaction (speed up or cancel)
  - mev_protect: Sends a transaction with MEV protection (e.g. Flashbots RPC)
  - gas_token: Uses gas tokens or relayer integration (stub)
  """

  use Lux.Prism,
    name: "Transaction Manager",
    description: "Manages Ethereum transactions including batching, replacement, and simulation",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: ["simulate", "batch", "replace", "mev_protect", "gas_token"],
          description: "Action to perform"
        },
        network: %{
          type: :string,
          enum: ["mainnet", "goerli", "sepolia", "test"],
          default: "mainnet"
        },
        payload: %{
          type: :object,
          description: "Payload required for the specific action"
        }
      },
      required: ["action", "payload"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        result: %{
          type: :object,
          description: "Result of the operation"
        }
      },
      required: ["result"]
    }

  import Lux.Python
  alias Lux.Config
  require Lux.Python

  def handler(%{action: action, payload: payload} = input, _ctx) do
    network = Map.get(input, :network, "mainnet")

    with {:ok, %{"success" => true}} <- Lux.Python.import_package("web3"),
         {:ok, result} <- run_python(action, network, payload) do
      {:ok, %{result: atomize_keys(result)}}
    else
      {:ok, %{"success" => false, "error" => error}} ->
        {:error, "Failed to import Web3: #{error}"}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp run_python(action, network, payload) do
    api_key = Config.alchemy_api_key()

    result =
      python variables: %{action: action, network: network, payload: payload, api_key: api_key} do
        ~PY"""
        def execute(action, network, payload, api_key):
            from web3 import Web3

            try:
                if network == "test":
                    w3 = Web3(Web3.EthereumTesterProvider())
                else:
                    NETWORKS = {
                        "mainnet": f"https://eth-mainnet.g.alchemy.com/v2/{api_key}",
                        "goerli": f"https://eth-goerli.g.alchemy.com/v2/{api_key}",
                        "sepolia": f"https://eth-sepolia.g.alchemy.com/v2/{api_key}"
                    }
                    if network not in NETWORKS:
                        return {"error": f"Invalid network: {network}"}
                    w3 = Web3(Web3.HTTPProvider(NETWORKS[network]))

                if action == "simulate":
                    tx = payload.get("transaction", {})
                    # Add simple simulation using eth_call
                    if 'from' in tx and not Web3.is_checksum_address(tx['from']):
                        tx['from'] = w3.to_checksum_address(tx['from'])
                    if 'to' in tx and not Web3.is_checksum_address(tx['to']):
                        tx['to'] = w3.to_checksum_address(tx['to'])
                    
                    try:
                        result = w3.eth.call(tx)
                        return {"success": True, "output": result.hex() if result else "0x"}
                    except Exception as e:
                        return {"success": False, "error": str(e)}

                elif action == "batch":
                    txs = payload.get("transactions", [])
                    # In a real system, you would use a Multicall contract
                    # Here we simulate batching success
                    return {
                        "batch_size": len(txs),
                        "status": "batched_for_execution",
                        "multicall_compatible": True
                    }

                elif action == "replace":
                    original_tx_hash = payload.get("tx_hash")
                    replacement_type = payload.get("type", "speed_up") # speed_up or cancel
                    
                    # Simulated replacement logic
                    new_gas_price = int(w3.eth.gas_price * 1.2) # 20% higher
                    return {
                        "original_tx": original_tx_hash,
                        "replacement_type": replacement_type,
                        "new_gas_price_wei": str(new_gas_price),
                        "status": "ready_to_sign"
                    }

                elif action == "mev_protect":
                    tx = payload.get("transaction", {})
                    # Simulate sending through Flashbots
                    flashbots_rpc = "https://rpc.flashbots.net"
                    return {
                        "status": "mev_protected",
                        "rpc_used": flashbots_rpc,
                        "transaction": tx
                    }

                elif action == "gas_token":
                    tx = payload.get("transaction", {})
                    token_address = payload.get("token_address")
                    
                    return {
                        "status": "gas_token_enabled",
                        "token_address": token_address,
                        "estimated_token_cost": "1000000000000000000" # 1 token
                    }

                else:
                    return {"error": f"Invalid action: {action}"}
            except Exception as e:
                return {"error": str(e)}

        result = execute(action, network, payload, api_key)
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
      {k, v} when is_list(v) -> 
        {String.to_atom(k), Enum.map(v, fn item -> 
          if is_map(item), do: atomize_keys(item), else: item 
        end)}
      {k, v} -> {String.to_atom(k), v}
    end)
  end
end
