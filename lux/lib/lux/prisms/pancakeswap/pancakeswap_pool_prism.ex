defmodule Lux.Prisms.Pancakeswap.PancakeswapPoolPrism do
  @moduledoc """
  A prism for managing liquidity pools on PancakeSwap V2.

  ## Example

      iex> Lux.Prisms.Pancakeswap.PancakeswapPoolPrism.handler(%{
      ...>   action: "add_liquidity",
      ...>   token_a: "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
      ...>   token_b: "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56",
      ...>   amount_a: "1000000000000000000",
      ...>   amount_b: "500000000000000000",
      ...>   chain_id: 56
      ...> }, %{})

  Reads config:
  - :pancakeswap_private_key - wallet private key
  """

  use Lux.Prism,
    name: "PancakeSwap Pool Management",
    description: "Manages liquidity pools on PancakeSwap V2",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "Action: add_liquidity, remove_liquidity, get_pool_info",
          enum: ["add_liquidity", "remove_liquidity", "get_pool_info"]
        },
        token_a: %{type: :string, description: "Token A contract address"},
        token_b: %{type: :string, description: "Token B contract address"},
        amount_a: %{type: :string, description: "Amount of token A in wei"},
        amount_b: %{type: :string, description: "Amount of token B in wei"},
        lp_amount: %{type: :string, description: "LP token amount for removal"},
        slippage: %{type: :integer, description: "Slippage in basis points", default: 50},
        chain_id: %{type: :integer, description: "Chain ID (56=BSC)", default: 56}
      },
      required: ["action", "token_a", "token_b"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        tx_hash: %{type: :string},
        lp_tokens: %{type: :string},
        reserve_a: %{type: :string},
        reserve_b: %{type: :string},
        status: %{type: :string}
      },
      required: ["status"]
    }

  import Lux.Python
  require Lux.Python
  require Logger

  alias Lux.Config

  # PancakeSwap V2 Router on BSC
  @router_v2 "0x10ED43C718714eb63d5aA57B78B54704E256024E"
  @factory_v2 "0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73"

  def handler(input, _ctx) do
    input = Map.put_new(input, :chain_id, 56)
    input = Map.put_new(input, :slippage, 50)

    with {:ok, private_key} <- get_private_key(),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("web3"),
         {:ok, result} <- execute_pool_action(private_key, input) do
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
    {:ok, Config.pancakeswap_private_key()}
  rescue
    _ -> {:error, :missing_private_key}
  end

  defp execute_pool_action(private_key, params) do
    python_result =
      python variables: %{
               private_key: private_key,
               action: params.action,
               token_a: params.token_a,
               token_b: params.token_b,
               amount_a: Map.get(params, :amount_a, "0"),
               amount_b: Map.get(params, :amount_b, "0"),
               lp_amount: Map.get(params, :lp_amount, "0"),
               slippage: params.slippage,
               router_address: @router_v2,
               factory_address: @factory_v2
             } do
        ~PY"""
        result = None
        try:
            from web3 import Web3
            from datetime import datetime, timedelta
            import json

            w3 = Web3(Web3.HTTPProvider("https://bsc-dataseed.binance.org/"))
            account = w3.eth.account.from_key(private_key)

            ROUTER_ABI = [
                {
                    "name": "addLiquidity",
                    "type": "function",
                    "inputs": [
                        {"name": "tokenA", "type": "address"},
                        {"name": "tokenB", "type": "address"},
                        {"name": "amountADesired", "type": "uint256"},
                        {"name": "amountBDesired", "type": "uint256"},
                        {"name": "amountAMin", "type": "uint256"},
                        {"name": "amountBMin", "type": "uint256"},
                        {"name": "to", "type": "address"},
                        {"name": "deadline", "type": "uint256"}
                    ]
                },
                {
                    "name": "removeLiquidity",
                    "type": "function",
                    "inputs": [
                        {"name": "tokenA", "type": "address"},
                        {"name": "tokenB", "type": "address"},
                        {"name": "liquidity", "type": "uint256"},
                        {"name": "amountAMin", "type": "uint256"},
                        {"name": "amountBMin", "type": "uint256"},
                        {"name": "to", "type": "address"},
                        {"name": "deadline", "type": "uint256"}
                    ]
                }
            ]

            FACTORY_ABI = [
                {
                    "name": "getPair",
                    "type": "function",
                    "inputs": [
                        {"name": "tokenA", "type": "address"},
                        {"name": "tokenB", "type": "address"}
                    ],
                    "outputs": [{"name": "pair", "type": "address"}]
                }
            ]

            ERC20_ABI = [
                {
                    "name": "allowance",
                    "type": "function",
                    "inputs": [
                        {"name": "owner", "type": "address"},
                        {"name": "spender", "type": "address"}
                    ],
                    "outputs": [{"name": "", "type": "uint256"}]
                },
                {
                    "name": "approve",
                    "type": "function",
                    "inputs": [
                        {"name": "spender", "type": "address"},
                        {"name": "amount", "type": "uint256"}
                    ],
                    "outputs": [{"name": "", "type": "bool"}]
                }
            ]

            PAIR_ABI = [
                {
                    "name": "getReserves",
                    "type": "function",
                    "outputs": [
                        {"name": "_reserve0", "type": "uint112"},
                        {"name": "_reserve1", "type": "uint112"},
                        {"name": "_blockTimestampLast", "type": "uint32"}
                    ]
                },
                {
                    "name": "totalSupply",
                    "type": "function",
                    "outputs": [{"name": "", "type": "uint256"}]
                }
            ]

            router = w3.eth.contract(
                address=Web3.to_checksum_address(router_address),
                abi=ROUTER_ABI
            )
            factory = w3.eth.contract(
                address=Web3.to_checksum_address(factory_address),
                abi=FACTORY_ABI
            )

            deadline = int((datetime.now() + timedelta(minutes=20)).timestamp())
            slippage_factor = 1 - (slippage / 10000)

            if action == "add_liquidity":
                amount_a_int = int(amount_a)
                amount_b_int = int(amount_b)
                amount_a_min = int(amount_a_int * slippage_factor)
                amount_b_min = int(amount_b_int * slippage_factor)
                max_uint = 2**256 - 1

                # Approve token_a
                token_a_contract = w3.eth.contract(address=Web3.to_checksum_address(token_a), abi=ERC20_ABI)
                if token_a_contract.functions.allowance(account.address, Web3.to_checksum_address(router_address)).call() < amount_a_int:
                    approve_tx = token_a_contract.functions.approve(Web3.to_checksum_address(router_address), max_uint).build_transaction({
                        "from": account.address, "nonce": w3.eth.get_transaction_count(account.address), "gas": 100000, "gasPrice": w3.eth.gas_price
                    })
                    signed = account.sign_transaction(approve_tx)
                    approve_receipt = w3.eth.wait_for_transaction_receipt(w3.eth.send_raw_transaction(signed.raw_transaction))
                    if approve_receipt["status"] == 0:
                        raise Exception("Token A approval reverted")

                # Approve token_b
                token_b_contract = w3.eth.contract(address=Web3.to_checksum_address(token_b), abi=ERC20_ABI)
                if token_b_contract.functions.allowance(account.address, Web3.to_checksum_address(router_address)).call() < amount_b_int:
                    approve_tx = token_b_contract.functions.approve(Web3.to_checksum_address(router_address), max_uint).build_transaction({
                        "from": account.address, "nonce": w3.eth.get_transaction_count(account.address), "gas": 100000, "gasPrice": w3.eth.gas_price
                    })
                    signed = account.sign_transaction(approve_tx)
                    approve_receipt = w3.eth.wait_for_transaction_receipt(w3.eth.send_raw_transaction(signed.raw_transaction))
                    if approve_receipt["status"] == 0:
                        raise Exception("Token B approval reverted")

                tx = router.functions.addLiquidity(
                    Web3.to_checksum_address(token_a),
                    Web3.to_checksum_address(token_b),
                    int(amount_a),
                    int(amount_b),
                    amount_a_min,
                    amount_b_min,
                    account.address,
                    deadline
                ).build_transaction({
                    "from": account.address,
                    "nonce": w3.eth.get_transaction_count(account.address),
                    "gas": 300000,
                    "gasPrice": w3.eth.gas_price
                })
                signed = account.sign_transaction(tx)
                tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
                receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
                if receipt["status"] == 0:
                    raise Exception("Add liquidity transaction reverted")
                result = {
                    "tx_hash": tx_hash.hex(),
                    "lp_tokens": "0",
                    "status": "success"
                }

            elif action == "remove_liquidity":
                lp_amount_int = int(lp_amount)
                # Approve LP token for router
                lp_contract = w3.eth.contract(address=Web3.to_checksum_address(token_a), abi=ERC20_ABI)
                if lp_contract.functions.allowance(account.address, Web3.to_checksum_address(router_address)).call() < lp_amount_int:
                    approve_tx = lp_contract.functions.approve(Web3.to_checksum_address(router_address), 2**256-1).build_transaction({
                        "from": account.address, "nonce": w3.eth.get_transaction_count(account.address), "gas": 100000, "gasPrice": w3.eth.gas_price
                    })
                    signed = account.sign_transaction(approve_tx)
                    approve_receipt = w3.eth.wait_for_transaction_receipt(w3.eth.send_raw_transaction(signed.raw_transaction))
                    if approve_receipt["status"] == 0:
                        raise Exception("LP token approval reverted")

                tx = router.functions.removeLiquidity(
                    Web3.to_checksum_address(token_a),
                    Web3.to_checksum_address(token_b),
                    lp_amount_int,
                    int(lp_amount_int * slippage_factor),
                    int(lp_amount_int * slippage_factor),
                    account.address,
                    deadline
                ).build_transaction({
                    "from": account.address,
                    "nonce": w3.eth.get_transaction_count(account.address),
                    "gas": 300000,
                    "gasPrice": w3.eth.gas_price
                })
                signed = account.sign_transaction(tx)
                tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
                receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
                if receipt["status"] == 0:
                    raise Exception("Remove liquidity transaction reverted")
                result = {
                    "tx_hash": tx_hash.hex(),
                    "status": "success"
                }

            elif action == "get_pool_info":
                pair_address = factory.functions.getPair(
                    Web3.to_checksum_address(token_a),
                    Web3.to_checksum_address(token_b)
                ).call()
                pair = w3.eth.contract(
                    address=Web3.to_checksum_address(pair_address),
                    abi=PAIR_ABI
                )
                reserves = pair.functions.getReserves().call()
                total_supply = pair.functions.totalSupply().call()
                result = {
                    "reserve_a": str(reserves[0]),
                    "reserve_b": str(reserves[1]),
                    "lp_tokens": str(total_supply),
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
