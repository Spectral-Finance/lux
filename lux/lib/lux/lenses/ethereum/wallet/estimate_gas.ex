defmodule Lux.Lenses.Ethereum.Wallet.EstimateGas do
  @moduledoc """
  A lens for estimating gas requirements for Ethereum transactions.

  Returns gas limit estimate, current gas price, and estimated total cost
  in ETH for a transaction on any EVM-compatible chain.

  ## Examples

      iex> EstimateGas.focus(%{
      ...>   from: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
      ...>   to: "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
      ...>   value_wei: "1000000000000000000",
      ...>   network: "mainnet"
      ...> }, %{agent: %{name: "TestAgent"}})
      {:ok, %{
        gas_limit: 21000,
        gas_price_gwei: "20.5",
        max_fee_per_gas_gwei: "25.0",
        priority_fee_gwei: "1.0",
        estimated_cost_eth: "0.00043",
        network: "mainnet"
      }}
  """

  use Lux.Lens,
    name: "Estimate Gas",
    description: "Estimates gas limit and fee requirements for an Ethereum transaction",
    schema: %{
      type: :object,
      properties: %{
        from: %{
          type: :string,
          description: "Sender address"
        },
        to: %{
          type: :string,
          description: "Recipient address or contract"
        },
        value_wei: %{
          type: :string,
          description: "ETH value to send in Wei (default: '0')",
          default: "0"
        },
        data: %{
          type: :string,
          description: "Transaction calldata for contract interactions (default: '0x')",
          default: "0x"
        },
        network: %{
          type: :string,
          description: "EVM network",
          enum: ["mainnet", "sepolia", "base", "polygon", "arbitrum", "optimism", "test"],
          default: "mainnet"
        },
        rpc_url: %{
          type: :string,
          description: "Custom RPC URL"
        }
      },
      required: ["from", "to"]
    }

  import Lux.Python
  require Lux.Python
  require Logger

  alias Lux.Config

  @networks %{
    "mainnet" => "https://eth-mainnet.g.alchemy.com/v2/",
    "sepolia" => "https://eth-sepolia.g.alchemy.com/v2/",
    "base" => "https://base-mainnet.g.alchemy.com/v2/",
    "polygon" => "https://polygon-mainnet.g.alchemy.com/v2/",
    "arbitrum" => "https://arb-mainnet.g.alchemy.com/v2/",
    "optimism" => "https://opt-mainnet.g.alchemy.com/v2/"
  }

  @impl true
  def focus(input, _agent) do
    network = Map.get(input, :network, "mainnet")

    with {:ok, rpc_url} <- resolve_rpc(input, network),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("web3"),
         {:ok, result} <- estimate(input, rpc_url, network) do
      {:ok, result}
    else
      {:ok, %{"success" => false, "error" => err}} ->
        {:error, "Failed to import web3: #{err}"}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp resolve_rpc(%{rpc_url: url}, _) when is_binary(url) and url != "", do: {:ok, url}
  defp resolve_rpc(_, "test"), do: {:ok, "test"}
  defp resolve_rpc(_, network) do
    api_key = Config.alchemy_api_key()
    case Map.fetch(@networks, network) do
      {:ok, base} -> {:ok, base <> api_key}
      :error -> {:error, "Unknown network: #{network}"}
    end
  end

  defp estimate(input, rpc_url, network) do
    result =
      python variables: %{
        from_addr: Map.get(input, :from, ""),
        to_addr: Map.get(input, :to, ""),
        value_wei: Map.get(input, :value_wei, "0"),
        data: Map.get(input, :data, "0x"),
        rpc_url: rpc_url,
        network: network
      } do
        ~PY"""
        from web3 import Web3

        try:
            if network == "test" or rpc_url == "test":
                w3 = Web3(Web3.EthereumTesterProvider())
            else:
                w3 = Web3(Web3.HTTPProvider(rpc_url))

            if not w3.is_connected():
                raise Exception("Cannot connect to node")

            # Estimate gas limit
            tx_params = {
                "from": w3.to_checksum_address(from_addr),
                "to": w3.to_checksum_address(to_addr),
                "value": int(value_wei),
                "data": data if data else "0x",
            }

            gas_limit = w3.eth.estimate_gas(tx_params)

            # Get current fees
            latest_block = w3.eth.get_block("latest")
            base_fee_wei = latest_block.get("baseFeePerGas", 0)

            # Legacy gas price
            gas_price_wei = w3.eth.gas_price
            gas_price_gwei = float(Web3.from_wei(gas_price_wei, "gwei"))

            # EIP-1559 fees
            priority_fee_wei = w3.to_wei(1, "gwei")  # 1 gwei priority tip
            max_fee_wei = base_fee_wei * 2 + priority_fee_wei if base_fee_wei else gas_price_wei

            max_fee_gwei = float(Web3.from_wei(max_fee_wei, "gwei"))
            priority_fee_gwei = float(Web3.from_wei(priority_fee_wei, "gwei"))
            base_fee_gwei = float(Web3.from_wei(base_fee_wei, "gwei")) if base_fee_wei else 0

            # Estimated cost
            estimated_cost_wei = gas_limit * max_fee_wei
            estimated_cost_eth = float(Web3.from_wei(estimated_cost_wei, "ether"))

            {
                "gas_limit": gas_limit,
                "gas_price_gwei": str(round(gas_price_gwei, 4)),
                "base_fee_gwei": str(round(base_fee_gwei, 4)),
                "max_fee_per_gas_gwei": str(round(max_fee_gwei, 4)),
                "priority_fee_gwei": str(round(priority_fee_gwei, 4)),
                "estimated_cost_eth": str(round(estimated_cost_eth, 10)),
                "network": network
            }
        except Exception as e:
            {"error": str(e)}
        """
      end

    if Map.has_key?(result, "error") do
      {:error, result["error"]}
    else
      {:ok, %{
        gas_limit: result["gas_limit"],
        gas_price_gwei: result["gas_price_gwei"],
        base_fee_gwei: result["base_fee_gwei"],
        max_fee_per_gas_gwei: result["max_fee_per_gas_gwei"],
        priority_fee_gwei: result["priority_fee_gwei"],
        estimated_cost_eth: result["estimated_cost_eth"],
        network: result["network"]
      }}
    end
  end
end
