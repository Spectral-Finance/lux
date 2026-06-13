defmodule Lux.Prisms.Pancakeswap.PancakeswapFarmPrism do
  @moduledoc """
  A prism for yield farming on PancakeSwap MasterChef V2.

  ## Example

      iex> Lux.Prisms.Pancakeswap.PancakeswapFarmPrism.handler(%{
      ...>   action: "deposit",
      ...>   pool_id: 1,
      ...>   amount: "1000000000000000000",
      ...>   chain_id: 56
      ...> }, %{})

  Reads config:
  - :pancakeswap_private_key - wallet private key
  """

  use Lux.Prism,
    name: "PancakeSwap Yield Farming",
    description: "Manages yield farming on PancakeSwap MasterChef V2",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "Action: deposit, withdraw, harvest",
          enum: ["deposit", "withdraw", "harvest"]
        },
        pool_id: %{type: :integer, description: "MasterChef pool ID (pid)"},
        amount: %{type: :string, description: "Amount in wei (not needed for harvest)"},
        chain_id: %{type: :integer, description: "Chain ID (56=BSC)", default: 56}
      },
      required: ["action", "pool_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        tx_hash: %{type: :string},
        rewards_claimed: %{type: :string},
        status: %{type: :string}
      },
      required: ["status"]
    }

  import Lux.Python
  require Lux.Python
  require Logger

  alias Lux.Config

  # PancakeSwap MasterChef V2 on BSC
  @masterchef_v2 "0xa5f8C5Dbd5F286960b9d90548680aE5ebFf07652"

  @masterchef_abi [
    %{
      "name" => "deposit",
      "type" => "function",
      "inputs" => [
        %{"name" => "_pid", "type" => "uint256"},
        %{"name" => "_amount", "type" => "uint256"}
      ]
    },
    %{
      "name" => "withdraw",
      "type" => "function",
      "inputs" => [
        %{"name" => "_pid", "type" => "uint256"},
        %{"name" => "_amount", "type" => "uint256"}
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

    with {:ok, private_key} <- get_private_key(),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("web3"),
         {:ok, result} <- execute_farm_action(private_key, input) do
      {:ok, result}
    else
      {:error, :missing_private_key} ->
        {:error, "PancakeSwap private key is not configured"}
      {:ok, %{"success" => false, "error" => error}} ->
        {:error, "Failed to import required packages: #{error}"}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_private_key do
    case Config.pancakeswap_private_key() do
      nil -> {:error, :missing_private_key}
      key -> {:ok, key}
    end
  rescue
    _ -> {:error, :missing_private_key}
  end

  defp execute_farm_action(private_key, params) do
    python_result =
      python variables: %{
               private_key: private_key,
               action: params.action,
               pool_id: params.pool_id,
               amount: Map.get(params, :amount, "0"),
               masterchef_address: @masterchef_v2,
               abi: Jason.encode!(@masterchef_abi)
             } do
        ~PY"""
        result = None
        try:
            from web3 import Web3
            import json

            w3 = Web3(Web3.HTTPProvider("https://bsc-dataseed.binance.org/"))
            account = w3.eth.account.from_key(private_key)
            abi = json.loads(abi)

            masterchef = w3.eth.contract(
                address=Web3.to_checksum_address(masterchef_address),
                abi=abi
            )

            pending = masterchef.functions.pendingCake(
                pool_id, account.address
            ).call()

            if action == "deposit":
                tx = masterchef.functions.deposit(
                    pool_id, int(amount)
                ).build_transaction({
                    "from": account.address,
                    "nonce": w3.eth.get_transaction_count(account.address),
                    "gas": 300000,
                    "gasPrice": w3.eth.gas_price
                })
            elif action == "withdraw":
                tx = masterchef.functions.withdraw(
                    pool_id, int(amount)
                ).build_transaction({
                    "from": account.address,
                    "nonce": w3.eth.get_transaction_count(account.address),
                    "gas": 300000,
                    "gasPrice": w3.eth.gas_price
                })
            elif action == "harvest":
                # deposit 0 to harvest
                tx = masterchef.functions.deposit(
                    pool_id, 0
                ).build_transaction({
                    "from": account.address,
                    "nonce": w3.eth.get_transaction_count(account.address),
                    "gas": 200000,
                    "gasPrice": w3.eth.gas_price
                })

            signed = account.sign_transaction(tx)
            tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)

            result = {
                "tx_hash": tx_hash.hex(),
                "rewards_claimed": str(pending),
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
