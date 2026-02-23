defmodule Lux.Prisms.PancakeSwap.PancakeSwapRemoveLiquidityPrism do
  @moduledoc """
  A prism for removing liquidity from a PancakeSwap V2 pool.

  Burns LP tokens and withdraws the underlying token pair through the
  PancakeSwap V2 Router. Slippage is applied to both output amounts.

  ## Example

      iex> Lux.Prisms.PancakeSwap.PancakeSwapRemoveLiquidityPrism.run(%{
      ...>   token_a: "0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82",
      ...>   token_b: "0x55d398326f99059fF775485246999027B3197955",
      ...>   lp_amount: "500000000000000000000",
      ...>   slippage_bps: 50
      ...> })
      {:ok, %{
        token_a: "0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82",
        token_b: "0x55d398326f99059fF775485246999027B3197955",
        amount_a_received: "497500000000000000000",
        amount_b_received: "497500000000000000000",
        tx_hash: "0xghi...",
        gas_used: 200000,
        status: "success"
      }}

  The prism reads authentication from config:
  - :pancakeswap_private_key — BNB Chain private key
  - :pancakeswap_rpc_url — BNB Chain RPC URL
  """

  use Lux.Prism,
    name: "PancakeSwap Remove Liquidity",
    description: "Removes liquidity from a PancakeSwap V2 pool by burning LP tokens",
    input_schema: %{
      type: :object,
      properties: %{
        token_a: %{
          type: :string,
          description: "First token address in the pair",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        token_b: %{
          type: :string,
          description: "Second token address in the pair",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        lp_amount: %{
          type: :string,
          description: "Amount of LP tokens to burn (in wei)"
        },
        slippage_bps: %{
          type: :integer,
          description: "Max slippage in basis points",
          default: 50,
          minimum: 0,
          maximum: 5000
        },
        deadline_seconds: %{
          type: :integer,
          description: "Transaction deadline from now in seconds",
          default: 1200,
          minimum: 60
        },
        router_address: %{
          type: :string,
          description: "PancakeSwap V2 Router address (defaults to BSC mainnet)",
          default: "0x10ED43C718714eb63d5aA57B78B54704E256024E",
          pattern: "^0x[a-fA-F0-9]{40}$"
        }
      },
      required: ["token_a", "token_b", "lp_amount"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        token_a: %{type: :string, description: "First token address"},
        token_b: %{type: :string, description: "Second token address"},
        amount_a_received: %{type: :string, description: "Token A received (in wei)"},
        amount_b_received: %{type: :string, description: "Token B received (in wei)"},
        tx_hash: %{type: :string, description: "Transaction hash"},
        gas_used: %{type: :integer, description: "Gas consumed"},
        status: %{type: :string, description: "Operation result"}
      },
      required: ["token_a", "token_b", "amount_a_received", "amount_b_received", "tx_hash", "status"]
    }

  import Lux.Python
  alias Lux.Config
  require Lux.Python
  require Logger

  @default_router "0x10ED43C718714eb63d5aA57B78B54704E256024E"
  @default_rpc "https://bsc-dataseed.binance.org"

  def handler(%{token_a: token_a, token_b: token_b, lp_amount: lp_amount} = input, _ctx) do
    slippage = Map.get(input, :slippage_bps, 50)
    deadline_secs = Map.get(input, :deadline_seconds, 1200)
    router = Map.get(input, :router_address, @default_router)

    Logger.info("PancakeSwap remove liquidity: #{token_a}/#{token_b}, LP=#{lp_amount}")

    with {:ok, private_key} <- get_config(:pancakeswap_private_key, "PANCAKESWAP_PRIVATE_KEY"),
         {:ok, rpc_url} <- {:ok, get_rpc_url()},
         {:ok, result} <- remove_liquidity(rpc_url, private_key, router, token_a, token_b, lp_amount, slippage, deadline_secs) do
      {:ok, result |> Map.put(:token_a, token_a) |> Map.put(:token_b, token_b)}
    else
      {:error, :missing_config, key} -> {:error, "Missing configuration: #{key}"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_config(config_key, env_key) do
    case Config.get(config_key) do
      nil ->
        case System.get_env(env_key) do
          nil -> {:error, :missing_config, env_key}
          val -> {:ok, val}
        end
      val -> {:ok, val}
    end
  rescue
    _ ->
      case System.get_env(env_key) do
        nil -> {:error, :missing_config, env_key}
        val -> {:ok, val}
      end
  end

  defp get_rpc_url do
    case Config.get(:pancakeswap_rpc_url) do
      nil -> System.get_env("PANCAKESWAP_RPC_URL") || @default_rpc
      url -> url
    end
  rescue
    _ -> System.get_env("PANCAKESWAP_RPC_URL") || @default_rpc
  end

  defp remove_liquidity(rpc_url, private_key, router_addr, token_a, token_b,
                        lp_amount, slippage_bps, deadline_secs) do
    result =
      python variables: %{
               rpc_url: rpc_url,
               private_key: private_key,
               router_address: router_addr,
               token_a: token_a,
               token_b: token_b,
               lp_amount: lp_amount,
               slippage_bps: slippage_bps,
               deadline_seconds: deadline_secs
             } do
        ~PY"""
        from web3 import Web3
        from eth_account import Account
        import time

        ROUTER_ABI = [
            {"name": "removeLiquidity", "type": "function", "inputs": [
                {"name": "tokenA", "type": "address"},
                {"name": "tokenB", "type": "address"},
                {"name": "liquidity", "type": "uint256"},
                {"name": "amountAMin", "type": "uint256"},
                {"name": "amountBMin", "type": "uint256"},
                {"name": "to", "type": "address"},
                {"name": "deadline", "type": "uint256"}
            ], "outputs": [
                {"name": "amountA", "type": "uint256"},
                {"name": "amountB", "type": "uint256"}
            ]},
            {"name": "quote", "type": "function", "inputs": [
                {"name": "amountA", "type": "uint256"},
                {"name": "reserveA", "type": "uint256"},
                {"name": "reserveB", "type": "uint256"}
            ], "outputs": [{"name": "amountB", "type": "uint256"}]}
        ]

        PAIR_ABI = [
            {"name": "approve", "type": "function",
             "inputs": [{"name": "_spender", "type": "address"}, {"name": "_value", "type": "uint256"}],
             "outputs": [{"name": "", "type": "bool"}]},
            {"name": "allowance", "type": "function",
             "inputs": [{"name": "owner", "type": "address"}, {"name": "spender", "type": "address"}],
             "outputs": [{"name": "", "type": "uint256"}]},
            {"name": "getReserves", "type": "function", "inputs": [],
             "outputs": [
                 {"name": "_reserve0", "type": "uint112"},
                 {"name": "_reserve1", "type": "uint112"},
                 {"name": "_blockTimestampLast", "type": "uint32"}
             ]},
            {"name": "totalSupply", "type": "function", "inputs": [],
             "outputs": [{"name": "", "type": "uint256"}]},
            {"name": "token0", "type": "function", "inputs": [],
             "outputs": [{"name": "", "type": "address"}]}
        ]

        FACTORY_ABI = [
            {"name": "getPair", "type": "function",
             "inputs": [{"name": "tokenA", "type": "address"}, {"name": "tokenB", "type": "address"}],
             "outputs": [{"name": "pair", "type": "address"}]}
        ]

        FACTORY_ADDR = "0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73"

        try:
            w3 = Web3(Web3.HTTPProvider(rpc_url))
            account = Account.from_key(private_key)
            router = Web3.to_checksum_address(router_address)
            addr_a = Web3.to_checksum_address(token_a)
            addr_b = Web3.to_checksum_address(token_b)
            lp_amt = int(lp_amount)
            slippage_factor = (10000 - slippage_bps) / 10000
            deadline = int(time.time()) + deadline_seconds
            nonce = w3.eth.get_transaction_count(account.address)
            gas_price = w3.eth.gas_price

            # Get pair address from factory
            factory = w3.eth.contract(
                address=Web3.to_checksum_address(FACTORY_ADDR), abi=FACTORY_ABI
            )
            pair_addr = factory.functions.getPair(addr_a, addr_b).call()
            pair = w3.eth.contract(address=pair_addr, abi=PAIR_ABI)

            # Compute min amounts based on reserves and LP share
            reserves = pair.functions.getReserves().call()
            total_supply = pair.functions.totalSupply().call()
            token0 = pair.functions.token0().call()

            # Determine which reserve is A and which is B
            if token0.lower() == addr_a.lower():
                reserve_a, reserve_b = reserves[0], reserves[1]
            else:
                reserve_a, reserve_b = reserves[1], reserves[0]

            share = lp_amt / total_supply if total_supply > 0 else 0
            expected_a = int(reserve_a * share)
            expected_b = int(reserve_b * share)
            min_a = int(expected_a * slippage_factor)
            min_b = int(expected_b * slippage_factor)

            # Approve router to spend LP tokens
            allowance = pair.functions.allowance(account.address, router).call()
            if allowance < lp_amt:
                approve_tx = pair.functions.approve(router, lp_amt).build_transaction({
                    "from": account.address, "nonce": nonce,
                    "gas": 60000, "gasPrice": gas_price
                })
                signed_approve = account.sign_transaction(approve_tx)
                approve_hash = w3.eth.send_raw_transaction(signed_approve.raw_transaction)
                w3.eth.wait_for_transaction_receipt(approve_hash, timeout=120)
                nonce += 1

            router_contract = w3.eth.contract(address=router, abi=ROUTER_ABI)
            tx = router_contract.functions.removeLiquidity(
                addr_a, addr_b, lp_amt, min_a, min_b, account.address, deadline
            ).build_transaction({
                "from": account.address, "nonce": nonce,
                "gas": 250000, "gasPrice": gas_price
            })
            signed = account.sign_transaction(tx)
            tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
            receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=180)

            {
                "amount_a_received": str(min_a),
                "amount_b_received": str(min_b),
                "tx_hash": tx_hash.hex(),
                "gas_used": receipt.gasUsed,
                "status": "success" if receipt.status == 1 else "failed"
            }
        except Exception as e:
            {"error": str(e)}
        """
      end

    if Map.has_key?(result, "error") do
      {:error, result["error"]}
    else
      {:ok, %{
        amount_a_received: result["amount_a_received"],
        amount_b_received: result["amount_b_received"],
        tx_hash: result["tx_hash"],
        gas_used: result["gas_used"],
        status: result["status"]
      }}
    end
  end
end
