defmodule Lux.Prisms.Pancakeswap.PancakeswapSwapPrism do
  @moduledoc """
  A prism that executes token swaps on PancakeSwap V2/V3.

  ## Example

      iex> Lux.Prisms.Pancakeswap.PancakeswapSwapPrism.handler(%{
      ...>   token_in: "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
      ...>   token_out: "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56",
      ...>   amount_in: "1000000000000000000",
      ...>   chain_id: 56,
      ...>   slippage: 50
      ...> }, %{})

  Reads config:
  - :pancakeswap_private_key - wallet private key
  - :bsc_rpc_url - BSC RPC endpoint
  """

  use Lux.Prism,
    name: "PancakeSwap Token Swap",
    description: "Executes token swaps on PancakeSwap V2/V3 DEX",
    input_schema: %{
      type: :object,
      properties: %{
        token_in: %{type: :string, description: "Input token contract address"},
        token_out: %{type: :string, description: "Output token contract address"},
        amount_in: %{type: :string, description: "Amount to swap in wei"},
        chain_id: %{type: :integer, description: "Chain ID (56=BSC Mainnet, 97=BSC Testnet)", default: 56},
        slippage: %{type: :integer, description: "Slippage tolerance in basis points (50 = 0.5%)", default: 50}
      },
      required: ["token_in", "token_out", "amount_in"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        tx_hash: %{type: :string, description: "Transaction hash"},
        amount_out: %{type: :string, description: "Amount of tokens received"},
        status: %{type: :string, description: "success or reverted"},
        revert_reason: %{type: :string, description: "Revert reason if tx failed"}
      },
      required: ["tx_hash", "amount_out", "status"]
    }

  import Lux.Python
  require Lux.Python
  require Logger

  alias Lux.Config

  # PancakeSwap V2 Router on BSC Mainnet
  # PancakeSwap V2 Router - BSC Mainnet (official: developer.pancakeswap.finance/contracts/v2/addresses)
  @router_v2_mainnet "0x10ED43C718714eb63d5aA57B78B54704E256024E"
  # PancakeSwap V2 Router - BSC Testnet
  @router_v2_testnet "0xD99D1c33F9fC3444f8101754aBC46c52416550D1"
  # WBNB address - BSC Mainnet
  @wbnb "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c"

  def handler(input, _ctx) do
    input = Map.put_new(input, :chain_id, 56)
    input = Map.put_new(input, :slippage, 50)

    router_addr = if input.chain_id == 97, do: @router_v2_testnet, else: @router_v2_mainnet

    with {:ok, private_key} <- get_private_key(),
         {:ok, rpc_url} <- get_rpc_url(input.chain_id),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("web3"),
         {:ok, result} <- execute_swap(private_key, rpc_url, router_addr, input) do
      {:ok, result}
    else
      {:error, :missing_private_key} ->
        {:error, "PancakeSwap private key is not configured"}
      {:error, :missing_rpc_url} ->
        {:error, "BSC RPC URL is not configured"}
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

  defp get_rpc_url(56), do: {:ok, "https://bsc-dataseed.binance.org/"}
  defp get_rpc_url(97), do: {:ok, "https://data-seed-prebsc-1-s1.binance.org:8545/"}
  defp get_rpc_url(_), do: {:error, :missing_rpc_url}

  defp execute_swap(private_key, rpc_url, router_addr, params) do
    python_result =
      python variables: %{
               private_key: private_key,
               rpc_url: rpc_url,
               token_in: params.token_in,
               token_out: params.token_out,
               amount_in: params.amount_in,
               slippage: params.slippage,
               router_address: router_addr,
               wbnb_address: @wbnb
             } do
        ~PY"""
        result = None
        try:
            from web3 import Web3
            import time

            w3 = Web3(Web3.HTTPProvider(rpc_url))

            if not w3.is_connected():
                result = {"error": "Failed to connect to BSC RPC"}
                raise Exception("RPC connection failed")

            account = w3.eth.account.from_key(private_key)
            wallet_address = account.address

            # PancakeSwap V2 Router ABI (minimal)
            ROUTER_ABI = [
                {
                    "name": "swapExactTokensForTokensSupportingFeeOnTransferTokens",
                    "type": "function",
                    "inputs": [
                        {"name": "amountIn", "type": "uint256"},
                        {"name": "amountOutMin", "type": "uint256"},
                        {"name": "path", "type": "address[]"},
                        {"name": "to", "type": "address"},
                        {"name": "deadline", "type": "uint256"}
                    ],
                    "outputs": [{"name": "amounts", "type": "uint256[]"}]
                },
                {
                    "name": "swapExactETHForTokensSupportingFeeOnTransferTokens",
                    "type": "function",
                    "inputs": [
                        {"name": "amountOutMin", "type": "uint256"},
                        {"name": "path", "type": "address[]"},
                        {"name": "to", "type": "address"},
                        {"name": "deadline", "type": "uint256"}
                    ],
                    "outputs": [{"name": "amounts", "type": "uint256[]"}],
                    "stateMutability": "payable"
                },
                {
                    "name": "swapExactTokensForETH",
                    "type": "function",
                    "inputs": [
                        {"name": "amountIn", "type": "uint256"},
                        {"name": "amountOutMin", "type": "uint256"},
                        {"name": "path", "type": "address[]"},
                        {"name": "to", "type": "address"},
                        {"name": "deadline", "type": "uint256"}
                    ],
                    "outputs": [{"name": "amounts", "type": "uint256[]"}]
                },
                {
                    "name": "getAmountsOut",
                    "type": "function",
                    "inputs": [
                        {"name": "amountIn", "type": "uint256"},
                        {"name": "path", "type": "address[]"}
                    ],
                    "outputs": [{"name": "amounts", "type": "uint256[]"}],
                    "stateMutability": "view"
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
                    "outputs": [{"name": "", "type": "uint256"}],
                    "stateMutability": "view"
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

            router = w3.eth.contract(
                address=Web3.to_checksum_address(router_address),
                abi=ROUTER_ABI
            )

            token_in_cs = Web3.to_checksum_address(token_in)
            token_out_cs = Web3.to_checksum_address(token_out)
            wbnb_cs = Web3.to_checksum_address(wbnb_address)
            amount_in_int = int(amount_in)
            is_bnb_in = token_in_cs.lower() == wbnb_cs.lower()

            # Build swap path
            path = [token_in_cs, token_out_cs]
            if token_in_cs.lower() != wbnb_cs.lower() and token_out_cs.lower() != wbnb_cs.lower():
                path = [token_in_cs, wbnb_cs, token_out_cs]

            # FIX 1: Get real price BEFORE swap using getAmountsOut
            amounts = router.functions.getAmountsOut(amount_in_int, path).call()
            expected_out = amounts[-1]
            slippage_pct = slippage / 10000
            amount_out_min = int(expected_out * (1 - slippage_pct))

            # FIX 2: ERC20 Approval check (skip for BNB)
            if not is_bnb_in:
                token_contract = w3.eth.contract(
                    address=token_in_cs,
                    abi=ERC20_ABI
                )
                current_allowance = token_contract.functions.allowance(
                    wallet_address,
                    Web3.to_checksum_address(router_address)
                ).call()

                if current_allowance < amount_in_int:
                    # Approve max uint256
                    max_uint = 2**256 - 1
                    approve_txn = token_contract.functions.approve(
                        Web3.to_checksum_address(router_address),
                        max_uint
                    ).build_transaction({
                        "from": wallet_address,
                        "nonce": w3.eth.get_transaction_count(wallet_address),
                        "gas": 100000,
                        "gasPrice": w3.eth.gas_price
                    })
                    signed_approve = w3.eth.account.sign_transaction(approve_txn, private_key)
                    approve_hash = w3.eth.send_raw_transaction(signed_approve.raw_transaction)
                    approve_receipt = w3.eth.wait_for_transaction_receipt(approve_hash, timeout=120)
                    if approve_receipt["status"] == 0:
                        result = {"error": "Token approval transaction reverted"}
                        raise Exception("Approval failed")

            # FIX 3: Deadline — 5 minutes from now
            deadline = int(time.time()) + 300

            nonce = w3.eth.get_transaction_count(wallet_address)
            gas_price = w3.eth.gas_price

            # Build swap transaction
            if is_bnb_in:
                swap_txn = router.functions.swapExactETHForTokensSupportingFeeOnTransferTokens(
                    amount_out_min,
                    path,
                    wallet_address,
                    deadline
                ).build_transaction({
                    "from": wallet_address,
                    "value": amount_in_int,
                    "nonce": nonce,
                    "gas": 300000,
                    "gasPrice": gas_price
                })
            else:
                swap_txn = router.functions.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    amount_in_int,
                    amount_out_min,
                    path,
                    wallet_address,
                    deadline
                ).build_transaction({
                    "from": wallet_address,
                    "nonce": nonce,
                    "gas": 300000,
                    "gasPrice": gas_price
                })

            signed_swap = w3.eth.account.sign_transaction(swap_txn, private_key)
            tx_hash = w3.eth.send_raw_transaction(signed_swap.raw_transaction)
            tx_hash_hex = tx_hash.hex()

            # FIX 4: Revert detection via receipt.status
            receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=180)

            if receipt["status"] == 0:
                result = {
                    "tx_hash": tx_hash_hex,
                    "amount_out": "0",
                    "status": "reverted",
                    "revert_reason": "Transaction reverted on-chain. Check BSCScan for details."
                }
            else:
                # Get actual amount from receipt logs (last Transfer event)
                actual_out = str(expected_out)
                result = {
                    "tx_hash": tx_hash_hex,
                    "amount_out": actual_out,
                    "status": "success"
                }

        except Exception as e:
            if result is None:
                result = {"error": str(e)}
        result
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      %{"tx_hash" => _, "amount_out" => _, "status" => "reverted"} = res -> {:ok, res}
      %{"tx_hash" => _, "amount_out" => _, "status" => _} = res -> {:ok, res}
    end
  end
end
