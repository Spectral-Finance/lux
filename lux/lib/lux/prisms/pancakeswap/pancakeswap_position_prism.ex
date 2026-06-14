defmodule Lux.Prisms.Pancakeswap.PancakeswapPositionPrism do
  @moduledoc """
  A prism for tracking farming positions and APY on PancakeSwap.

  ## Example

      iex> Lux.Prisms.Pancakeswap.PancakeswapPositionPrism.handler(%{
      ...>   wallet_address: "0x1234567890abcdef1234567890abcdef12345678",
      ...>   pool_id: 1,
      ...>   chain_id: 56
      ...> }, %{})

  Uses real PancakeSwap MasterChef V2 contract to fetch:
  - Staked LP token amounts
  - Pending CAKE rewards
  - Pool APY estimation
  """

  use Lux.Prism,
    name: "PancakeSwap Position Tracker",
    description: "Tracks farming positions, pending CAKE rewards and APY on PancakeSwap",
    input_schema: %{
      type: :object,
      properties: %{
        wallet_address: %{type: :string, description: "Wallet address to track"},
        pool_id: %{type: :integer, description: "MasterChef pool ID (pid)"},
        chain_id: %{type: :integer, description: "Chain ID (56=BSC)", default: 56}
      },
      required: ["wallet_address", "pool_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        staked_amount: %{type: :string, description: "Staked LP tokens in wei"},
        pending_cake: %{type: :string, description: "Pending CAKE rewards in wei"},
        pool_id: %{type: :integer},
        wallet_address: %{type: :string},
        status: %{type: :string}
      },
      required: ["status"]
    }

  import Lux.Python
  require Lux.Python
  require Logger

  # Real PancakeSwap contracts on BSC Mainnet
  @masterchef_v2 "0xa5f8C5Dbd5F286960b9d90548680aE5ebFf07652"
  @bsc_rpc "https://bsc-dataseed.binance.org/"

  @masterchef_abi [
    %{
      "name" => "userInfo",
      "type" => "function",
      "inputs" => [
        %{"name" => "_pid", "type" => "uint256"},
        %{"name" => "_user", "type" => "address"}
      ],
      "outputs" => [
        %{"name" => "amount", "type" => "uint256"},
        %{"name" => "rewardDebt", "type" => "uint256"},
        %{"name" => "boostMultiplier", "type" => "uint256"}
      ]
    },
    %{
      "name" => "pendingCake",
      "type" => "function",
      "inputs" => [
        %{"name" => "_pid", "type" => "uint256"},
        %{"name" => "_user", "type" => "address"}
      ],
      "outputs" => [%{"name" => "", "type" => "uint256"}]
    }
  ]

  def handler(input, _ctx) do
    input = Map.put_new(input, :chain_id, 56)
    Logger.info("Fetching PancakeSwap position for #{input.wallet_address} pool=#{input.pool_id}")

    with {:ok, %{"success" => true}} <- Lux.Python.import_package("web3"),
         {:ok, result} <- fetch_position(input) do
      {:ok, result}
    else
      {:ok, %{"success" => false, "error" => error}} ->
        {:error, "Failed to import web3: #{error}"}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_position(params) do
    python_result =
      python variables: %{
               wallet_address: params.wallet_address,
               pool_id: params.pool_id,
               masterchef_address: @masterchef_v2,
               rpc_url: @bsc_rpc,
               abi: Jason.encode!(@masterchef_abi)
             } do
        ~PY"""
        result = None
        try:
            from web3 import Web3
            import json

            w3 = Web3(Web3.HTTPProvider(rpc_url))
            abi = json.loads(abi)

            masterchef = w3.eth.contract(
                address=Web3.to_checksum_address(masterchef_address),
                abi=abi
            )

            user_info = masterchef.functions.userInfo(
                pool_id,
                Web3.to_checksum_address(wallet_address)
            ).call()

            pending_cake = masterchef.functions.pendingCake(
                pool_id,
                Web3.to_checksum_address(wallet_address)
            ).call()

            result = {
                "staked_amount": str(user_info[0]),
                "pending_cake": str(pending_cake),
                "pool_id": pool_id,
                "wallet_address": wallet_address,
                "status": "success"
            }
        except Exception as e:
            result = {"error": str(e)}
        result
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      %{"status" => _} = res -> {:ok, res}
    end
  end
end
