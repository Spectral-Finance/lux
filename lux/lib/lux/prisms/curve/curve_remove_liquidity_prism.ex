defmodule Lux.Prisms.Curve.CurveRemoveLiquidityPrism do
  @moduledoc """
  A prism for removing liquidity from a Curve Finance pool.

  Burns LP tokens and withdraws underlying tokens. Supports both balanced
  withdrawal (all tokens) and single-token withdrawal for 3-token pools.

  ## Example

      iex> Lux.Prisms.Curve.CurveRemoveLiquidityPrism.run(%{
      ...>   pool_address: "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7",
      ...>   lp_token_amount: "500000000000000000000",
      ...>   min_amounts: ["0", "0", "0"]
      ...> })
      {:ok, %{
        pool_address: "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7",
        amounts_received: ["497123456789", "501000000", "498000000"],
        tx_hash: "0xdef...",
        gas_used: 220000,
        status: "success"
      }}

  For single-token withdrawal, provide `coin_index`:

      iex> Lux.Prisms.Curve.CurveRemoveLiquidityPrism.run(%{
      ...>   pool_address: "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7",
      ...>   lp_token_amount: "500000000000000000000",
      ...>   coin_index: 1,
      ...>   min_amount: "490000000"
      ...> })

  The prism reads authentication from config:
  - :curve_private_key — Ethereum private key for signing transactions
  - :curve_rpc_url — Ethereum JSON-RPC endpoint URL
  """

  use Lux.Prism,
    name: "Curve Remove Liquidity",
    description: "Withdraws tokens from a Curve Finance pool by burning LP tokens",
    input_schema: %{
      type: :object,
      properties: %{
        pool_address: %{
          type: :string,
          description: "Curve pool contract address",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        lp_token_amount: %{
          type: :string,
          description: "Amount of LP tokens to burn (in wei)"
        },
        min_amounts: %{
          type: :array,
          description: "Min token amounts to receive per slot (slippage guard, in wei). For balanced withdrawal.",
          items: %{type: :string}
        },
        coin_index: %{
          type: :integer,
          description: "Token index for single-coin withdrawal (0-based). Omit for balanced withdrawal.",
          minimum: 0,
          maximum: 2
        },
        min_amount: %{
          type: :string,
          description: "Min amount for single-coin withdrawal (in wei). Required when coin_index is set.",
          default: "0"
        }
      },
      required: ["pool_address", "lp_token_amount"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        pool_address: %{type: :string, description: "Pool contract address"},
        amounts_received: %{
          type: :array,
          description: "Token amounts received per slot (in wei)",
          items: %{type: :string}
        },
        tx_hash: %{type: :string, description: "Transaction hash"},
        gas_used: %{type: :integer, description: "Gas consumed"},
        status: %{type: :string, description: "Operation result"}
      },
      required: ["pool_address", "amounts_received", "tx_hash", "status"]
    }

  import Lux.Python
  alias Lux.Config
  require Lux.Python
  require Logger

  def handler(%{pool_address: pool_address, lp_token_amount: lp_amount} = input, _ctx) do
    min_amounts = Map.get(input, :min_amounts, nil)
    coin_index = Map.get(input, :coin_index, nil)
    min_amount = Map.get(input, :min_amount, "0")
    Logger.info("Removing liquidity from Curve pool #{pool_address}, LP amount: #{lp_amount}")

    with {:ok, private_key} <- get_config(:curve_private_key, "CURVE_PRIVATE_KEY"),
         {:ok, rpc_url} <- get_config(:curve_rpc_url, "CURVE_RPC_URL"),
         {:ok, result} <- remove_liquidity(rpc_url, private_key, pool_address, lp_amount, min_amounts, coin_index, min_amount) do
      Logger.info("Removed liquidity from #{pool_address}: #{inspect(result)}")
      {:ok, Map.put(result, :pool_address, pool_address)}
    else
      {:error, :missing_config, key} ->
        {:error, "Missing configuration: #{key}"}
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

  defp remove_liquidity(rpc_url, private_key, pool_address, lp_amount, min_amounts, coin_index, min_amount) do
    result =
      python variables: %{
               rpc_url: rpc_url,
               private_key: private_key,
               pool_address: pool_address,
               lp_token_amount: lp_amount,
               min_amounts: min_amounts,
               coin_index: coin_index,
               min_amount: min_amount
             } do
        ~PY"""
        from web3 import Web3
        from eth_account import Account

        POOL_ABI = [
            {"name": "remove_liquidity", "type": "function", "inputs": [
                {"name": "_amount", "type": "uint256"},
                {"name": "min_amounts", "type": "uint256[3]"}
            ], "outputs": [{"name": "", "type": "uint256[3]"}]},
            {"name": "remove_liquidity_one_coin", "type": "function", "inputs": [
                {"name": "_token_amount", "type": "uint256"},
                {"name": "i", "type": "int128"},
                {"name": "min_amount", "type": "uint256"}
            ], "outputs": [{"name": "", "type": "uint256"}]},
            {"name": "calc_withdraw_one_coin", "type": "function", "inputs": [
                {"name": "_token_amount", "type": "uint256"},
                {"name": "i", "type": "int128"}
            ], "outputs": [{"name": "", "type": "uint256"}]}
        ]

        try:
            w3 = Web3(Web3.HTTPProvider(rpc_url))
            account = Account.from_key(private_key)
            pool_addr = Web3.to_checksum_address(pool_address)
            pool = w3.eth.contract(address=pool_addr, abi=POOL_ABI)
            lp_amt = int(lp_token_amount)
            nonce = w3.eth.get_transaction_count(account.address)
            gas_price = w3.eth.gas_price

            if coin_index is not None:
                # Single-coin withdrawal
                min_out = int(min_amount) if min_amount else 0
                if min_out == 0:
                    estimated = pool.functions.calc_withdraw_one_coin(lp_amt, coin_index).call()
                    min_out = int(estimated * 9950 // 10000)  # 0.5% slippage

                tx = pool.functions.remove_liquidity_one_coin(
                    lp_amt, coin_index, min_out
                ).build_transaction({
                    "from": account.address,
                    "nonce": nonce,
                    "gas": 250000,
                    "gasPrice": gas_price
                })
                signed = account.sign_transaction(tx)
                tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
                receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=180)

                n_coins = 3
                amounts_out = ["0"] * n_coins
                amounts_out[coin_index] = str(min_out)
            else:
                # Balanced withdrawal
                mins = [int(a) for a in (min_amounts or ["0", "0", "0"])]
                tx = pool.functions.remove_liquidity(lp_amt, mins).build_transaction({
                    "from": account.address,
                    "nonce": nonce,
                    "gas": 300000,
                    "gasPrice": gas_price
                })
                signed = account.sign_transaction(tx)
                tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
                receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=180)
                amounts_out = [str(m) for m in mins]

            {
                "amounts_received": amounts_out,
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
        amounts_received: result["amounts_received"],
        tx_hash: result["tx_hash"],
        gas_used: result["gas_used"],
        status: result["status"]
      }}
    end
  end
end
