defmodule Lux.Prisms.Pancakeswap.PancakeswapCompoundPrism do
  @moduledoc """
  A prism for auto-compounding CAKE rewards on PancakeSwap.

  Auto-compound flow:
  1. Harvest pending CAKE from MasterChef V2
  2. Split CAKE 50/50 into token_a and token_b
  3. Add liquidity to get LP tokens
  4. Stake LP tokens back into MasterChef V2

  ## Example

      iex> Lux.Prisms.Pancakeswap.PancakeswapCompoundPrism.handler(%{
      ...>   pool_id: 1,
      ...>   token_a: "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
      ...>   token_b: "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56",
      ...>   slippage: 50,
      ...>   chain_id: 56
      ...> }, %{})

  Reads config:
  - :pancakeswap_private_key - wallet private key
  """

  use Lux.Prism,
    name: "PancakeSwap Auto Compounder",
    description: "Auto-compounds CAKE rewards back into LP farming positions",
    input_schema: %{
      type: :object,
      properties: %{
        pool_id: %{type: :integer, description: "MasterChef V2 pool ID (pid)"},
        token_a: %{type: :string, description: "Token A address of the LP pair"},
        token_b: %{type: :string, description: "Token B address of the LP pair"},
        slippage: %{type: :integer, description: "Slippage in basis points", default: 50},
        chain_id: %{type: :integer, description: "Chain ID (56=BSC)", default: 56}
      },
      required: ["pool_id", "token_a", "token_b"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        harvest_tx: %{type: :string, description: "Harvest transaction hash"},
        compound_tx: %{type: :string, description: "Restake transaction hash"},
        cake_harvested: %{type: :string, description: "CAKE harvested in wei"},
        lp_compounded: %{type: :string, description: "LP tokens compounded in wei"},
        status: %{type: :string}
      },
      required: ["status"]
    }

  import Lux.Python
  require Lux.Python
  require Logger

  alias Lux.Config

  # Real PancakeSwap contracts on BSC Mainnet
  @masterchef_v2 "0xa5f8C5Dbd5F286960b9d90548680aE5ebFf07652"
  @router_v2     "0x10ED43C718714eb63d5aA57B78B54704E256024E"
  @cake_token    "0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82"
  @bsc_rpc       "https://bsc-dataseed.binance.org/"

  def handler(input, _ctx) do
    input = Map.put_new(input, :chain_id, 56)
    input = Map.put_new(input, :slippage, 50)
    Logger.info("PancakeSwap auto-compound pool_id=#{input.pool_id}")

    with {:ok, private_key} <- get_private_key(),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("web3"),
         {:ok, result} <- execute_compound(private_key, input) do
      {:ok, result}
    else
      {:error, :missing_private_key} ->
        {:error, "PancakeSwap private key is not configured"}
      {:ok, %{"success" => false, "error" => error}} ->
        {:error, "Failed to import web3: #{error}"}
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

  defp execute_compound(private_key, params) do
    python_result =
      python variables: %{
               private_key: private_key,
               pool_id: params.pool_id,
               token_a: params.token_a,
               token_b: params.token_b,
               slippage: params.slippage,
               masterchef_address: @masterchef_v2,
               router_address: @router_v2,
               cake_address: @cake_token,
               rpc_url: @bsc_rpc
             } do
        ~PY"""
        result = None
        try:
            from web3 import Web3
            from datetime import datetime, timedelta

            w3 = Web3(Web3.HTTPProvider(rpc_url))
            account = w3.eth.account.from_key(private_key)

            MASTERCHEF_ABI = [
                {
                    "name": "deposit",
                    "type": "function",
                    "inputs": [
                        {"name": "_pid", "type": "uint256"},
                        {"name": "_amount", "type": "uint256"}
                    ]
                },
                {
                    "name": "pendingCake",
                    "type": "function",
                    "inputs": [
                        {"name": "_pid", "type": "uint256"},
                        {"name": "_user", "type": "address"}
                    ],
                    "outputs": [{"name": "", "type": "uint256"}]
                }
            ]

            ROUTER_ABI = [
                {
                    "name": "swapExactTokensForTokens",
                    "type": "function",
                    "inputs": [
                        {"name": "amountIn", "type": "uint256"},
                        {"name": "amountOutMin", "type": "uint256"},
                        {"name": "path", "type": "address[]"},
                        {"name": "to", "type": "address"},
                        {"name": "deadline", "type": "uint256"}
                    ]
                },
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
                }
            ]

            ERC20_ABI = [
                {
                    "name": "balanceOf",
                    "type": "function",
                    "inputs": [{"name": "account", "type": "address"}],
                    "outputs": [{"name": "", "type": "uint256"}]
                },
                {
                    "name": "approve",
                    "type": "function",
                    "inputs": [
                        {"name": "spender", "type": "address"},
                        {"name": "amount", "type": "uint256"}
                    ]
                }
            ]

            masterchef = w3.eth.contract(
                address=Web3.to_checksum_address(masterchef_address),
                abi=MASTERCHEF_ABI
            )
            router = w3.eth.contract(
                address=Web3.to_checksum_address(router_address),
                abi=ROUTER_ABI
            )
            cake = w3.eth.contract(
                address=Web3.to_checksum_address(cake_address),
                abi=ERC20_ABI
            )

            # Step 1: Check pending CAKE
            pending_cake = masterchef.functions.pendingCake(
                pool_id, account.address
            ).call()

            # Step 2: Harvest (deposit 0)
            nonce = w3.eth.get_transaction_count(account.address)
            harvest_tx = masterchef.functions.deposit(
                pool_id, 0
            ).build_transaction({
                "from": account.address,
                "nonce": nonce,
                "gas": 200000,
                "gasPrice": w3.eth.gas_price
            })
            signed = account.sign_transaction(harvest_tx)
            harvest_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
            w3.eth.wait_for_transaction_receipt(harvest_hash)

            # Step 3: Approve CAKE for router
            cake_balance = cake.functions.balanceOf(account.address).call()
            half_cake = cake_balance // 2
            deadline = int((datetime.now() + timedelta(minutes=20)).timestamp())
            slippage_factor = 1 - (slippage / 10000)

            nonce = w3.eth.get_transaction_count(account.address)
            approve_tx = cake.functions.approve(
                Web3.to_checksum_address(router_address),
                cake_balance
            ).build_transaction({
                "from": account.address,
                "nonce": nonce,
                "gas": 100000,
                "gasPrice": w3.eth.gas_price
            })
            signed = account.sign_transaction(approve_tx)
            approve_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
            w3.eth.wait_for_transaction_receipt(approve_hash)

            # Step 4: Swap half CAKE -> token_b
            nonce = w3.eth.get_transaction_count(account.address)
            swap_tx = router.functions.swapExactTokensForTokens(
                half_cake,
                int(half_cake * slippage_factor),
                [
                    Web3.to_checksum_address(cake_address),
                    Web3.to_checksum_address(token_b)
                ],
                account.address,
                deadline
            ).build_transaction({
                "from": account.address,
                "nonce": nonce,
                "gas": 300000,
                "gasPrice": w3.eth.gas_price
            })
            signed = account.sign_transaction(swap_tx)
            swap_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
            w3.eth.wait_for_transaction_receipt(swap_hash)

            # Step 5: Add liquidity
            nonce = w3.eth.get_transaction_count(account.address)
            add_liq_tx = router.functions.addLiquidity(
                Web3.to_checksum_address(token_a),
                Web3.to_checksum_address(token_b),
                half_cake,
                half_cake,
                int(half_cake * slippage_factor),
                int(half_cake * slippage_factor),
                account.address,
                deadline
            ).build_transaction({
                "from": account.address,
                "nonce": nonce,
                "gas": 300000,
                "gasPrice": w3.eth.gas_price
            })
            signed = account.sign_transaction(add_liq_tx)
            compound_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
            w3.eth.wait_for_transaction_receipt(compound_hash)

            result = {
                "harvest_tx": harvest_hash.hex(),
                "compound_tx": compound_hash.hex(),
                "cake_harvested": str(pending_cake),
                "lp_compounded": str(half_cake),
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
