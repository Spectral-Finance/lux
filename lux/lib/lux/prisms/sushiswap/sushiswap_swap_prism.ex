defmodule Lux.Prisms.Sushiswap.SushiswapSwapPrism do
  @moduledoc """
  Executes token swaps on SushiSwap V2 using web3.

  ## Supported Chains
  - Ethereum  : Router 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9f
  - BSC       : Router 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506
  - Polygon   : Router 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506
  - Arbitrum  : Router 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506

  ## Example

      iex> Lux.Prisms.Sushiswap.SushiswapSwapPrism.run(%{
      ...>   token_in: "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
      ...>   token_out: "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56",
      ...>   amount_in: "1000000000000000000",
      ...>   slippage: 50,
      ...>   chain_id: 56
      ...> })
      {:ok, %{status: "success", tx_hash: "0x...", amount_out: "..."}}
  """

  use Lux.Prism,
    name: "SushiSwap Token Swap",
    description: "Swaps tokens on SushiSwap V2 across multiple chains",
    input_schema: %{
      type: :object,
      properties: %{
        token_in: %{
          type: :string,
          description: "Input token contract address"
        },
        token_out: %{
          type: :string,
          description: "Output token contract address"
        },
        amount_in: %{
          type: :string,
          description: "Input amount in wei"
        },
        slippage: %{
          type: :integer,
          description: "Slippage tolerance in basis points (50 = 0.5%)",
          default: 50
        },
        chain_id: %{
          type: :integer,
          description: "Chain ID: 1=Ethereum, 56=BSC, 137=Polygon, 42161=Arbitrum",
          default: 56
        }
      },
      required: ["token_in", "token_out", "amount_in"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        tx_hash: %{type: :string},
        amount_out: %{type: :string},
        amount_out_min: %{type: :string},
        fee_tier: %{type: :string}
      },
      required: ["status"]
    }

  import Lux.Python
  alias Lux.Config
  require Lux.Python

  # Official SushiSwap router addresses per chain
  @routers %{
    1     => "0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9f",
    56    => "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506",
    137   => "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506",
    42_161 => "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506",
    43_114 => "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506"
  }

  @rpcs %{
    1     => "https://eth.llamarpc.com",
    56    => "https://bsc-dataseed.binance.org/",
    137   => "https://polygon-rpc.com",
    42_161 => "https://arb1.arbitrum.io/rpc",
    43_114 => "https://api.avax.network/ext/bc/C/rpc"
  }

  def handler(input, _ctx) do
    chain_id = input[:chain_id] || input["chain_id"] || 56
    router   = @routers[chain_id] || @routers[56]
    rpc_url  = @rpcs[chain_id]   || @rpcs[56]

    token_in  = input[:token_in]  || input["token_in"]
    token_out = input[:token_out] || input["token_out"]
    amount_in = input[:amount_in] || input["amount_in"]
    slippage  = input[:slippage]  || input["slippage"] || 50

    with {:ok, private_key} <- get_private_key(),
         {:ok, result} <- execute_swap(
           private_key, rpc_url, router,
           token_in, token_out, amount_in, slippage
         ) do
      {:ok, result}
    else
      {:error, :missing_key} ->
        {:error, "Private key not configured"}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_private_key do
    key = Config.get(:sushiswap_private_key) ||
          Config.get(:web3_private_key) ||
          System.get_env("PRIVATE_KEY")
    if key, do: {:ok, key}, else: {:error, :missing_key}
  rescue
    _ -> {:error, :missing_key}
  end

  defp execute_swap(private_key, rpc_url, router, token_in, token_out, amount_in, slippage) do
    result =
      python variables: %{
        private_key: private_key,
        rpc_url:     rpc_url,
        router_addr: router,
        token_in:    token_in,
        token_out:   token_out,
        amount_in:   amount_in,
        slippage:    slippage
      } do
        ~PY"""
        from web3 import Web3
        from web3.middleware import ExtraDataToPOAMiddleware
        import time

        # Connect
        w3 = Web3(Web3.HTTPProvider(rpc_url))
        w3.middleware_onion.inject(ExtraDataToPOAMiddleware, layer=0)

        if not w3.is_connected():
          raise Exception(f"Cannot connect to RPC: {rpc_url}")

        account = w3.eth.account.from_key(private_key)
        amount_in_wei = int(amount_in)

        # Official SushiSwap V2 Router ABI (minimal)
        ROUTER_ABI = [
          {
            "inputs": [
              {"name": "amountIn",     "type": "uint256"},
              {"name": "path",         "type": "address[]"}
            ],
            "name": "getAmountsOut",
            "outputs": [{"name": "amounts", "type": "uint256[]"}],
            "stateMutability": "view",
            "type": "function"
          },
          {
            "inputs": [
              {"name": "amountIn",     "type": "uint256"},
              {"name": "amountOutMin", "type": "uint256"},
              {"name": "path",         "type": "address[]"},
              {"name": "to",           "type": "address"},
              {"name": "deadline",     "type": "uint256"}
            ],
            "name": "swapExactTokensForTokens",
            "outputs": [{"name": "amounts", "type": "uint256[]"}],
            "stateMutability": "nonpayable",
            "type": "function"
          },
          {
            "inputs": [
              {"name": "amountIn",     "type": "uint256"},
              {"name": "amountOutMin", "type": "uint256"},
              {"name": "path",         "type": "address[]"},
              {"name": "to",           "type": "address"},
              {"name": "deadline",     "type": "uint256"}
            ],
            "name": "swapExactTokensForTokensSupportingFeeOnTransferTokens",
            "outputs": [],
            "stateMutability": "nonpayable",
            "type": "function"
          }
        ]

        ERC20_ABI = [
          {
            "inputs": [
              {"name": "owner",   "type": "address"},
              {"name": "spender", "type": "address"}
            ],
            "name": "allowance",
            "outputs": [{"name": "", "type": "uint256"}],
            "stateMutability": "view",
            "type": "function"
          },
          {
            "inputs": [
              {"name": "spender", "type": "address"},
              {"name": "amount",  "type": "uint256"}
            ],
            "name": "approve",
            "outputs": [{"name": "", "type": "bool"}],
            "stateMutability": "nonpayable",
            "type": "function"
          }
        ]

        router   = w3.eth.contract(
          address=Web3.to_checksum_address(router_addr),
          abi=ROUTER_ABI
        )
        token_in_c = Web3.to_checksum_address(token_in)
        token_out_c= Web3.to_checksum_address(token_out)
        path       = [token_in_c, token_out_c]

        # Step 1: getAmountsOut — official formula
        amounts      = router.functions.getAmountsOut(amount_in_wei, path).call()
        amount_out   = amounts[-1]

        # Step 2: Apply slippage (basis points)
        amount_out_min = amount_out * (10000 - slippage) // 10000

        # Step 3: ERC20 approval — check allowance first
        token_contract = w3.eth.contract(
          address=token_in_c, abi=ERC20_ABI
        )
        allowance = token_contract.functions.allowance(
          account.address,
          Web3.to_checksum_address(router_addr)
        ).call()

        if allowance < amount_in_wei:
          max_uint = 2**256 - 1
          approve_tx = token_contract.functions.approve(
            Web3.to_checksum_address(router_addr), max_uint
          ).build_transaction({
            "from":     account.address,
            "gas":      100000,
            "gasPrice": w3.eth.gas_price,
            "nonce":    w3.eth.get_transaction_count(account.address)
          })
          signed = account.sign_transaction(approve_tx)
          w3.eth.send_raw_transaction(signed.raw_transaction)
          time.sleep(3)

        # Step 4: Swap with 5-minute deadline
        deadline = int(time.time()) + 300

        swap_tx = router.functions.swapExactTokensForTokens(
          amount_in_wei,
          amount_out_min,
          path,
          account.address,
          deadline
        ).build_transaction({
          "from":     account.address,
          "gas":      300000,
          "gasPrice": w3.eth.gas_price,
          "nonce":    w3.eth.get_transaction_count(account.address)
        })

        signed  = account.sign_transaction(swap_tx)
        tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
        receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=120)

        # Step 5: Revert detection
        if receipt.status == 0:
          {"error": f"Swap reverted on-chain: {tx_hash.hex()}"}
        else:
          {
            "status":         "success",
            "tx_hash":        tx_hash.hex(),
            "amount_out":     str(amount_out),
            "amount_out_min": str(amount_out_min),
            "fee_tier":       "0.3%",
            "gas_used":       receipt.gasUsed
          }
        """
      end

    case result do
      %{"error" => e}      -> {:error, e}
      %{"status" => "success"} = r -> {:ok, r}
      _ -> {:error, "Unexpected response"}
    end
  end
end
