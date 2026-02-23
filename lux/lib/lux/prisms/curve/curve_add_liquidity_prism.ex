defmodule Lux.Prisms.Curve.CurveAddLiquidityPrism do
  @moduledoc """
  A prism for adding liquidity to a Curve Finance stablecoin pool.

  Deposits one or more tokens into a Curve pool in exchange for LP tokens.
  Supports both 2-token and 3-token pools (e.g. 3pool: DAI/USDC/USDT).

  ## Example

      iex> Lux.Prisms.Curve.CurveAddLiquidityPrism.run(%{
      ...>   pool_address: "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7",
      ...>   token_amounts: ["1000000000000000000000", "0", "0"],
      ...>   min_mint_amount: "0",
      ...>   slippage_bps: 50
      ...> })
      {:ok, %{
        pool_address: "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7",
        lp_tokens_minted: "999234567890123456789",
        tx_hash: "0xabc...",
        gas_used: 180000,
        status: "success"
      }}

  The prism reads authentication from config:
  - :curve_private_key — Ethereum private key for signing transactions
  - :curve_rpc_url — Ethereum JSON-RPC endpoint URL
  """

  use Lux.Prism,
    name: "Curve Add Liquidity",
    description: "Deposits tokens into a Curve Finance pool to receive LP tokens",
    input_schema: %{
      type: :object,
      properties: %{
        pool_address: %{
          type: :string,
          description: "Curve pool contract address (e.g. 3pool: 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7)",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        token_amounts: %{
          type: :array,
          description: "Amounts for each token in the pool (in wei). Use '0' for tokens not being deposited.",
          items: %{type: :string}
        },
        min_mint_amount: %{
          type: :string,
          description: "Minimum LP tokens to receive (slippage protection, in wei). Use '0' to skip.",
          default: "0"
        },
        slippage_bps: %{
          type: :integer,
          description: "Max acceptable slippage in basis points (e.g. 50 = 0.5%). Used to compute min_mint_amount if not set.",
          minimum: 0,
          maximum: 10000
        }
      },
      required: ["pool_address", "token_amounts"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        pool_address: %{type: :string, description: "Pool contract address"},
        lp_tokens_minted: %{type: :string, description: "LP token amount received (in wei)"},
        tx_hash: %{type: :string, description: "Transaction hash"},
        gas_used: %{type: :integer, description: "Gas consumed by the transaction"},
        status: %{type: :string, description: "Operation result"}
      },
      required: ["pool_address", "lp_tokens_minted", "tx_hash", "status"]
    }

  import Lux.Python
  alias Lux.Config
  require Lux.Python
  require Logger

  def handler(%{pool_address: pool_address, token_amounts: token_amounts} = input, _ctx) do
    min_mint = Map.get(input, :min_mint_amount, "0")
    slippage_bps = Map.get(input, :slippage_bps, 50)
    Logger.info("Adding liquidity to Curve pool #{pool_address}")

    with {:ok, private_key} <- get_config(:curve_private_key, "CURVE_PRIVATE_KEY"),
         {:ok, rpc_url} <- get_config(:curve_rpc_url, "CURVE_RPC_URL"),
         {:ok, result} <- add_liquidity(rpc_url, private_key, pool_address, token_amounts, min_mint, slippage_bps) do
      Logger.info("Added liquidity to #{pool_address}: #{inspect(result)}")
      {:ok, Map.put(result, :pool_address, pool_address)}
    else
      {:error, :missing_config, key} ->
        {:error, "Missing configuration: #{key}. Set via config or environment variable."}
      {:error, reason} ->
        {:error, reason}
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

  defp add_liquidity(rpc_url, private_key, pool_address, token_amounts, min_mint, slippage_bps) do
    result =
      python variables: %{
               rpc_url: rpc_url,
               private_key: private_key,
               pool_address: pool_address,
               token_amounts: token_amounts,
               min_mint_amount: min_mint,
               slippage_bps: slippage_bps
             } do
        ~PY"""
        from web3 import Web3
        from eth_account import Account

        POOL_ABI_2 = [
            {"name": "add_liquidity", "type": "function", "inputs": [
                {"name": "amounts", "type": "uint256[2]"},
                {"name": "min_mint_amount", "type": "uint256"}
            ], "outputs": [{"name": "", "type": "uint256"}]},
            {"name": "calc_token_amount", "type": "function", "inputs": [
                {"name": "amounts", "type": "uint256[2]"},
                {"name": "is_deposit", "type": "bool"}
            ], "outputs": [{"name": "", "type": "uint256"}]},
            {"name": "get_virtual_price", "type": "function", "inputs": [],
             "outputs": [{"name": "", "type": "uint256"}]}
        ]

        POOL_ABI_3 = [
            {"name": "add_liquidity", "type": "function", "inputs": [
                {"name": "amounts", "type": "uint256[3]"},
                {"name": "min_mint_amount", "type": "uint256"}
            ], "outputs": [{"name": "", "type": "uint256"}]},
            {"name": "calc_token_amount", "type": "function", "inputs": [
                {"name": "amounts", "type": "uint256[3]"},
                {"name": "is_deposit", "type": "bool"}
            ], "outputs": [{"name": "", "type": "uint256"}]},
            {"name": "get_virtual_price", "type": "function", "inputs": [],
             "outputs": [{"name": "", "type": "uint256"}]}
        ]

        try:
            w3 = Web3(Web3.HTTPProvider(rpc_url))
            account = Account.from_key(private_key)
            pool_addr = Web3.to_checksum_address(pool_address)
            amounts = [int(a) for a in token_amounts]
            n_tokens = len(amounts)

            pool_abi = POOL_ABI_3 if n_tokens == 3 else POOL_ABI_2
            pool = w3.eth.contract(address=pool_addr, abi=pool_abi)

            # Compute min_mint if not set or zero
            min_mint = int(min_mint_amount)
            if min_mint == 0 and slippage_bps > 0:
                expected = pool.functions.calc_token_amount(amounts, True).call()
                min_mint = int(expected * (10000 - slippage_bps) // 10000)

            nonce = w3.eth.get_transaction_count(account.address)
            gas_price = w3.eth.gas_price

            if n_tokens == 3:
                tx = pool.functions.add_liquidity(amounts, min_mint).build_transaction({
                    "from": account.address,
                    "nonce": nonce,
                    "gas": 350000,
                    "gasPrice": gas_price
                })
            else:
                tx = pool.functions.add_liquidity(amounts, min_mint).build_transaction({
                    "from": account.address,
                    "nonce": nonce,
                    "gas": 250000,
                    "gasPrice": gas_price
                })

            signed = account.sign_transaction(tx)
            tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
            receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=180)

            # Estimate LP tokens from logs (Transfer event from pool)
            lp_minted = "0"
            for log in receipt.logs:
                if len(log.topics) >= 3 and log.address.lower() == pool_addr.lower():
                    # Transfer event: topic[0]=Transfer sig, topic[2]=to address
                    to_addr = "0x" + log.topics[2].hex()[-40:]
                    if to_addr.lower() == account.address.lower():
                        lp_minted = str(int.from_bytes(log.data[:32], "big"))
                        break

            {
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
        lp_tokens_minted: result["lp_tokens_minted"],
        tx_hash: result["tx_hash"],
        gas_used: result["gas_used"],
        status: result["status"]
      }}
    end
  end
end
