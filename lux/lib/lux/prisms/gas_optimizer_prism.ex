defmodule Lux.Prisms.GasOptimizerPrism do
  @moduledoc """
  Gas optimization and transaction management prism.

  Supports:
  - gas_prediction: Predicts gas prices
  - priority_fee: Optimizes priority fees
  - cost_analysis: Cost analysis reporting
  """

  use Lux.Prism,
    name: "Gas Optimizer",
    description: "Performs gas optimization and analysis",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: ["predict", "priority_fee", "cost_analysis"],
          description: "Action to perform"
        },
        network: %{
          type: :string,
          enum: ["mainnet", "goerli", "sepolia", "test"],
          default: "mainnet"
        },
        gas_limit: %{
          type: :integer,
          description: "Gas limit for cost analysis"
        }
      },
      required: ["action"]
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

  def handler(%{action: action} = input, _ctx) do
    network = Map.get(input, :network, "mainnet")
    gas_limit = Map.get(input, :gas_limit, 21000)

    with {:ok, %{"success" => true}} <- Lux.Python.import_package("web3"),
         {:ok, result} <- run_python(action, network, gas_limit) do
      {:ok, %{result: atomize_keys(result)}}
    else
      {:ok, %{"success" => false, "error" => error}} ->
        {:error, "Failed to import Web3: #{error}"}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp run_python(action, network, gas_limit) do
    api_key = Config.alchemy_api_key()

    result =
      python variables: %{action: action, network: network, gas_limit: gas_limit, api_key: api_key} do
        ~PY"""
        def execute(action, network, gas_limit, api_key):
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

                if action == "predict":
                    # Simple prediction based on gas price
                    gas_price = w3.eth.gas_price
                    return {
                        "gas_price_wei": str(gas_price),
                        "gas_price_gwei": float(Web3.from_wei(gas_price, 'gwei')),
                        "estimated_base_fee_gwei": float(Web3.from_wei(gas_price, 'gwei')) * 0.9 # heuristic
                    }
                elif action == "priority_fee":
                    # Priority fee optimization using max priority fee
                    max_priority_fee = w3.eth.max_priority_fee
                    return {
                        "optimized_priority_fee_wei": str(max_priority_fee),
                        "optimized_priority_fee_gwei": float(Web3.from_wei(max_priority_fee, 'gwei'))
                    }
                elif action == "cost_analysis":
                    gas_price = w3.eth.gas_price
                    cost_wei = gas_price * gas_limit
                    return {
                        "estimated_cost_wei": str(cost_wei),
                        "estimated_cost_eth": float(Web3.from_wei(cost_wei, 'ether')),
                        "gas_limit_used": gas_limit
                    }
                else:
                    return {"error": f"Invalid action: {action}"}
            except Exception as e:
                return {"error": str(e)}

        result = execute(action, network, gas_limit, api_key)
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
end
