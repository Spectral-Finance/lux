defmodule Lux.Prisms.Pancakeswap.PancakeswapV3SwapPrism do
  @moduledoc """
  A prism that executes token swaps on PancakeSwap V3.

  PancakeSwap V3 uses concentrated liquidity (similar to Uniswap V3).
  Supports multiple fee tiers: 100, 500, 2500, 10000 bps.

  ## Example

      iex> Lux.Prisms.Pancakeswap.PancakeswapV3SwapPrism.handler(%{
      ...>   token_in: "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
      ...>   token_out: "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56",
      ...>   amount_in: "1000000000000000000",
      ...>   fee: 500,
      ...>   chain_id: 56
      ...> }, %{})

  Fee tiers:
  - 100  = 0.01% (stable pairs)
  - 500  = 0.05% (stable pairs)
  - 2500 = 0.25% (standard pairs)
  - 10000 = 1%  (exotic pairs)

  Reads config:
  - :pancakeswap_private_key - wallet private key
  """

  use Lux.Prism,
    name: "PancakeSwap V3 Token Swap",
    description: "Executes token swaps on PancakeSwap V3 with concentrated liquidity",
    input_schema: %{
      type: :object,
      properties: %{
        token_in: %{type: :string, description: "Input token contract address"},
        token_out: %{type: :string, description: "Output token contract address"},
        amount_in: %{type: :string, description: "Amount to swap in wei"},
        fee: %{
          type: :integer,
          description: "Pool fee tier: 100, 500, 2500, 10000",
          enum: [100, 500, 2500, 10_000],
          default: 500
        },
        slippage: %{type: :integer, description: "Slippage in basis points", default: 50},
        chain_id: %{type: :integer, description: "Chain ID (56=BSC)", default: 56}
      },
      required: ["token_in", "token_out", "amount_in"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        tx_hash: %{type: :string},
        amount_out: %{type: :string},
        fee_tier: %{type: :integer},
        status: %{type: :string}
      },
      required: ["status"]
    }

  import Lux.Python
  require Lux.Python
  require Logger

  alias Lux.Config

  # Real PancakeSwap V3 contracts on BSC Mainnet
  @router_v3 "0x13f4EA83D0bd40E75C8222255bc855a974568Dd4"
  @bsc_rpc   "https://bsc-dataseed.binance.org/"

  @router_v3_abi [
    %{
      "name" => "exactInputSingle",
      "type" => "function",
      "inputs" => [
        %{
          "name" => "params",
          "type" => "tuple",
          "components" => [
            %{"name" => "tokenIn", "type" => "address"},
            %{"name" => "tokenOut", "type" => "address"},
            %{"name" => "fee", "type" => "uint24"},
            %{"name" => "recipient", "type" => "address"},
            %{"name" => "deadline", "type" => "uint256"},
            %{"name" => "amountIn", "type" => "uint256"},
            %{"name" => "amountOutMinimum", "type" => "uint256"},
            %{"name" => "sqrtPriceLimitX96", "type" => "uint160"}
          ]
        }
      ],
      "outputs" => [%{"name" => "amountOut", "type" => "uint256"}]
    }
  ]

  def handler(input, _ctx) do
    input = Map.put_new(input, :chain_id, 56)
    input = Map.put_new(input, :fee, 500)
    input = Map.put_new(input, :slippage, 50)

    with {:ok, private_key} <- get_private_key(),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("web3"),
         {:ok, result} <- execute_swap(private_key, input) do
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
    {:ok, Config.pancakeswap_private_key()}
  rescue
    _ -> {:error, :missing_private_key}
  end

  defp execute_swap(private_key, params) do
    python_result =
      python variables: %{
               private_key: private_key,
               token_in: params.token_in,
               token_out: params.token_out,
               amount_in: params.amount_in,
               fee: params.fee,
               slippage: params.slippage,
               router_address: @router_v3,
               rpc_url: @bsc_rpc,
               abi: Jason.encode!(@router_v3_abi)
             } do
        ~PY"""
        result = None
        try:
            from web3 import Web3
            from datetime import datetime, timedelta
            import json

            w3 = Web3(Web3.HTTPProvider(rpc_url))
            account = w3.eth.account.from_key(private_key)
            abi = json.loads(abi)

            router = w3.eth.contract(
                address=Web3.to_checksum_address(router_address),
                abi=abi
            )

            deadline = int((datetime.now() + timedelta(minutes=20)).timestamp())
            slippage_factor = 1 - (slippage / 10000)
            amount_in_int = int(amount_in)
            amount_out_min = int(amount_in_int * slippage_factor)

            # ERC20 approval check
            ERC20_ABI = [
                {"name": "allowance", "type": "function",
                 "inputs": [{"name": "owner", "type": "address"}, {"name": "spender", "type": "address"}],
                 "outputs": [{"name": "", "type": "uint256"}]},
                {"name": "approve", "type": "function",
                 "inputs": [{"name": "spender", "type": "address"}, {"name": "amount", "type": "uint256"}],
                 "outputs": [{"name": "", "type": "bool"}]}
            ]
            token_contract = w3.eth.contract(address=Web3.to_checksum_address(token_in), abi=ERC20_ABI)
            if token_contract.functions.allowance(account.address, Web3.to_checksum_address(router_address)).call() < amount_in_int:
                approve_tx = token_contract.functions.approve(Web3.to_checksum_address(router_address), 2**256-1).build_transaction({
                    "from": account.address, "nonce": w3.eth.get_transaction_count(account.address), "gas": 100000, "gasPrice": w3.eth.gas_price
                })
                signed = account.sign_transaction(approve_tx)
                approve_receipt = w3.eth.wait_for_transaction_receipt(w3.eth.send_raw_transaction(signed.raw_transaction))
                if approve_receipt["status"] == 0:
                    raise Exception("Token approval reverted")

            tx = router.functions.exactInputSingle((
                Web3.to_checksum_address(token_in),
                Web3.to_checksum_address(token_out),
                fee,
                account.address,
                deadline,
                amount_in_int,
                amount_out_min,
                0
            )).build_transaction({
                "from": account.address,
                "nonce": w3.eth.get_transaction_count(account.address),
                "gas": 300000,
                "gasPrice": w3.eth.gas_price
            })

            signed = account.sign_transaction(tx)
            tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
            receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
            if receipt["status"] == 0:
                result = {
                    "tx_hash": tx_hash.hex(),
                    "amount_out": "0",
                    "fee_tier": fee,
                    "status": "reverted",
                    "revert_reason": "V3 swap transaction reverted on-chain"
                }
            else:
                result = {
                    "tx_hash": tx_hash.hex(),
                    "amount_out": str(amount_out_min),
                    "fee_tier": fee,
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
