defmodule Lux.Prisms.PancakeSwap.PancakeSwapAddLiquidityPrism do
  @moduledoc """
  A prism for adding liquidity to a PancakeSwap V2 pool on BNB Chain.

  Deposits a token pair into a PancakeSwap V2 pool through the Router,
  receiving LP tokens that can be staked in yield farming.

  Supports any token pair. Use WBNB address for BNB-paired pools.

  ## Example

      iex> Lux.Prisms.PancakeSwap.PancakeSwapAddLiquidityPrism.run(%{
      ...>   token_a: "0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82",
      ...>   token_b: "0x55d398326f99059fF775485246999027B3197955",
      ...>   amount_a_desired: "1000000000000000000000",
      ...>   amount_b_desired: "1000000000000000000000",
      ...>   slippage_bps: 50
      ...> })
      {:ok, %{
        token_a: "0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82",
        token_b: "0x55d398326f99059fF775485246999027B3197955",
        amount_a_added: "999500000000000000000",
        amount_b_added: "999500000000000000000",
        lp_tokens_minted: "999000000000000000000",
        tx_hash: "0xabc...",
        gas_used: 180000,
        status: "success"
      }}

  The prism reads authentication from config:
  - :pancakeswap_private_key — BNB Chain private key for signing
  - :pancakeswap_rpc_url — BNB Chain JSON-RPC endpoint URL
  """

  use Lux.Prism,
    name: "PancakeSwap Add Liquidity",
    description: "Deposits a token pair into a PancakeSwap V2 pool and receives LP tokens",
    input_schema: %{
      type: :object,
      properties: %{
        token_a: %{
          type: :string,
          description: "Address of first token in the pair",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        token_b: %{
          type: :string,
          description: "Address of second token in the pair",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        amount_a_desired: %{
          type: :string,
          description: "Desired amount of token A to add (in wei)"
        },
        amount_b_desired: %{
          type: :string,
          description: "Desired amount of token B to add (in wei)"
        },
        slippage_bps: %{
          type: :integer,
          description: "Max slippage in basis points (e.g. 50 = 0.5%)",
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
      required: ["token_a", "token_b", "amount_a_desired", "amount_b_desired"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        token_a: %{type: :string, description: "First token address"},
        token_b: %{type: :string, description: "Second token address"},
        amount_a_added: %{type: :string, description: "Token A amount added (in wei)"},
        amount_b_added: %{type: :string, description: "Token B amount added (in wei)"},
        lp_tokens_minted: %{type: :string, description: "LP tokens received (in wei)"},
        tx_hash: %{type: :string, description: "Transaction hash"},
        gas_used: %{type: :integer, description: "Gas consumed"},
        status: %{type: :string, description: "Operation result"}
      },
      required: ["token_a", "token_b", "lp_tokens_minted", "tx_hash", "status"]
    }

  import Lux.Python
  alias Lux.Config
  require Lux.Python
  require Logger

  @default_router "0x10ED43C718714eb63d5aA57B78B54704E256024E"
  @default_rpc "https://bsc-dataseed.binance.org"

  def handler(%{token_a: token_a, token_b: token_b,
                amount_a_desired: amount_a, amount_b_desired: amount_b} = input, _ctx) do
    slippage = Map.get(input, :slippage_bps, 50)
    deadline_secs = Map.get(input, :deadline_seconds, 1200)
    router = Map.get(input, :router_address, @default_router)

    Logger.info("PancakeSwap add liquidity: #{token_a}/#{token_b}")

    with {:ok, private_key} <- get_config(:pancakeswap_private_key, "PANCAKESWAP_PRIVATE_KEY"),
         {:ok, rpc_url} <- {:ok, get_rpc_url()},
         {:ok, result} <- add_liquidity(rpc_url, private_key, router, token_a, token_b, amount_a, amount_b, slippage, deadline_secs) do
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

  defp add_liquidity(rpc_url, private_key, router_addr, token_a, token_b,
                     amount_a, amount_b, slippage_bps, deadline_secs) do
    result =
      python variables: %{
               rpc_url: rpc_url,
               private_key: private_key,
               router_address: router_addr,
               token_a: token_a,
               token_b: token_b,
               amount_a_desired: amount_a,
               amount_b_desired: amount_b,
               slippage_bps: slippage_bps,
               deadline_seconds: deadline_secs
             } do
        ~PY"""
        from web3 import Web3
        from eth_account import Account
        import time

        ROUTER_ABI = [
            {"name": "addLiquidity", "type": "function", "inputs": [
                {"name": "tokenA", "type": "address"},
                {"name": "tokenB", "type": "address"},
                {"name": "amountADesired", "type": "uint256"},
                {"name": "amountBDesired", "type": "uint256"},
                {"name": "amountAMin", "type": "uint256"},
                {"name": "amountBMin", "type": "uint256"},
                {"name": "to", "type": "address"},
                {"name": "deadline", "type": "uint256"}
            ], "outputs": [
                {"name": "amountA", "type": "uint256"},
                {"name": "amountB", "type": "uint256"},
                {"name": "liquidity", "type": "uint256"}
            ]}
        ]

        ERC20_ABI = [
            {"name": "approve", "type": "function",
             "inputs": [{"name": "_spender", "type": "address"}, {"name": "_value", "type": "uint256"}],
             "outputs": [{"name": "", "type": "bool"}]},
            {"name": "allowance", "type": "function",
             "inputs": [{"name": "owner", "type": "address"}, {"name": "spender", "type": "address"}],
             "outputs": [{"name": "", "type": "uint256"}]}
        ]

        try:
            w3 = Web3(Web3.HTTPProvider(rpc_url))
            account = Account.from_key(private_key)
            router = Web3.to_checksum_address(router_address)
            addr_a = Web3.to_checksum_address(token_a)
            addr_b = Web3.to_checksum_address(token_b)
            amt_a = int(amount_a_desired)
            amt_b = int(amount_b_desired)

            slippage_factor = (10000 - slippage_bps) / 10000
            min_a = int(amt_a * slippage_factor)
            min_b = int(amt_b * slippage_factor)
            deadline = int(time.time()) + deadline_seconds
            nonce = w3.eth.get_transaction_count(account.address)
            gas_price = w3.eth.gas_price

            # Approve router for both tokens
            for addr, amt in [(addr_a, amt_a), (addr_b, amt_b)]:
                token_contract = w3.eth.contract(address=addr, abi=ERC20_ABI)
                allowance = token_contract.functions.allowance(account.address, router).call()
                if allowance < amt:
                    approve_tx = token_contract.functions.approve(router, amt).build_transaction({
                        "from": account.address, "nonce": nonce,
                        "gas": 60000, "gasPrice": gas_price
                    })
                    signed = account.sign_transaction(approve_tx)
                    approve_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
                    w3.eth.wait_for_transaction_receipt(approve_hash, timeout=120)
                    nonce += 1

            router_contract = w3.eth.contract(address=router, abi=ROUTER_ABI)
            tx = router_contract.functions.addLiquidity(
                addr_a, addr_b, amt_a, amt_b, min_a, min_b, account.address, deadline
            ).build_transaction({
                "from": account.address, "nonce": nonce,
                "gas": 250000, "gasPrice": gas_price
            })
            signed = account.sign_transaction(tx)
            tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
            receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=180)

            # Parse return values from receipt logs (Transfer events)
            lp_minted = "0"
            for log in receipt.logs:
                if len(log.topics) >= 3:
                    to_raw = log.topics[2].hex()
                    to_addr = "0x" + to_raw[-40:]
                    if to_addr.lower() == account.address.lower() and log.address.lower() not in [addr_a.lower(), addr_b.lower()]:
                        lp_minted = str(int.from_bytes(log.data[:32], "big"))
                        break

            {
                "amount_a_added": str(min_a),
                "amount_b_added": str(min_b),
                "lp_tokens_minted": lp_minted,
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
        amount_a_added: result["amount_a_added"],
        amount_b_added: result["amount_b_added"],
        lp_tokens_minted: result["lp_tokens_minted"],
        tx_hash: result["tx_hash"],
        gas_used: result["gas_used"],
        status: result["status"]
      }}
    end
  end
end
