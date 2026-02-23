defmodule Lux.Prisms.Curve.CurveExchangePrism do
  @moduledoc """
  A prism for swapping tokens through a Curve Finance pool.

  Curve pools offer highly efficient stablecoin swaps with minimal slippage.
  Supports direct pool exchanges for 2-token and 3-token pools.

  ## Example

      iex> Lux.Prisms.Curve.CurveExchangePrism.run(%{
      ...>   pool_address: "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7",
      ...>   from_index: 0,
      ...>   to_index: 2,
      ...>   amount: "1000000000000000000000",
      ...>   min_dy: "999000000"
      ...> })
      {:ok, %{
        pool_address: "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7",
        from_index: 0,
        to_index: 2,
        amount_in: "1000000000000000000000",
        amount_out: "999876543",
        slippage_bps: 12,
        tx_hash: "0xjkl...",
        gas_used: 130000,
        status: "success"
      }}

  Token indices for 3pool (0xbEbc44...):
    0 = DAI (18 decimals), 1 = USDC (6 decimals), 2 = USDT (6 decimals)

  The prism reads authentication from config:
  - :curve_private_key — Ethereum private key
  - :curve_rpc_url — Ethereum JSON-RPC endpoint URL
  """

  use Lux.Prism,
    name: "Curve Exchange",
    description: "Swaps tokens through a Curve pool with slippage protection",
    input_schema: %{
      type: :object,
      properties: %{
        pool_address: %{
          type: :string,
          description: "Curve pool contract address",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        from_index: %{
          type: :integer,
          description: "Source token index in the pool (0-based)",
          minimum: 0,
          maximum: 2
        },
        to_index: %{
          type: :integer,
          description: "Destination token index in the pool (0-based)",
          minimum: 0,
          maximum: 2
        },
        amount: %{
          type: :string,
          description: "Amount of source token to swap (in wei)"
        },
        min_dy: %{
          type: :string,
          description: "Minimum output amount accepted (slippage guard, in wei). Use '0' to auto-calculate with 0.5% slippage.",
          default: "0"
        }
      },
      required: ["pool_address", "from_index", "to_index", "amount"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        pool_address: %{type: :string, description: "Pool contract address"},
        from_index: %{type: :integer, description: "Source token index"},
        to_index: %{type: :integer, description: "Destination token index"},
        amount_in: %{type: :string, description: "Input amount (in wei)"},
        amount_out: %{type: :string, description: "Output amount received (in wei)"},
        slippage_bps: %{type: :integer, description: "Actual slippage in basis points"},
        tx_hash: %{type: :string, description: "Transaction hash"},
        gas_used: %{type: :integer, description: "Gas consumed"},
        status: %{type: :string, description: "Operation result"}
      },
      required: ["pool_address", "from_index", "to_index", "amount_in", "amount_out", "tx_hash", "status"]
    }

  import Lux.Python
  alias Lux.Config
  require Lux.Python
  require Logger

  def handler(%{pool_address: pool_address, from_index: from_idx, to_index: to_idx, amount: amount} = input, _ctx) do
    min_dy = Map.get(input, :min_dy, "0")
    Logger.info("Curve exchange #{amount} via #{pool_address}: index #{from_idx} → #{to_idx}")

    with {:ok, private_key} <- get_config(:curve_private_key, "CURVE_PRIVATE_KEY"),
         {:ok, rpc_url} <- get_config(:curve_rpc_url, "CURVE_RPC_URL"),
         {:ok, result} <- exchange(rpc_url, private_key, pool_address, from_idx, to_idx, amount, min_dy) do
      Logger.info("Exchange complete: #{result.amount_in} → #{result.amount_out}")
      {:ok, result |> Map.put(:pool_address, pool_address) |> Map.put(:from_index, from_idx) |> Map.put(:to_index, to_idx)}
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

  defp exchange(rpc_url, private_key, pool_address, from_idx, to_idx, amount, min_dy) do
    result =
      python variables: %{
               rpc_url: rpc_url,
               private_key: private_key,
               pool_address: pool_address,
               from_index: from_idx,
               to_index: to_idx,
               amount: amount,
               min_dy: min_dy
             } do
        ~PY"""
        from web3 import Web3
        from eth_account import Account

        POOL_ABI = [
            {"name": "exchange", "type": "function", "inputs": [
                {"name": "i", "type": "int128"},
                {"name": "j", "type": "int128"},
                {"name": "dx", "type": "uint256"},
                {"name": "min_dy", "type": "uint256"}
            ], "outputs": [{"name": "", "type": "uint256"}]},
            {"name": "get_dy", "type": "function", "inputs": [
                {"name": "i", "type": "int128"},
                {"name": "j", "type": "int128"},
                {"name": "dx", "type": "uint256"}
            ], "outputs": [{"name": "", "type": "uint256"}]}
        ]

        try:
            w3 = Web3(Web3.HTTPProvider(rpc_url))
            account = Account.from_key(private_key)
            pool_addr = Web3.to_checksum_address(pool_address)
            pool = w3.eth.contract(address=pool_addr, abi=POOL_ABI)
            dx = int(amount)
            nonce = w3.eth.get_transaction_count(account.address)
            gas_price = w3.eth.gas_price

            # Quote expected output
            expected_dy = pool.functions.get_dy(from_index, to_index, dx).call()

            # Apply 0.5% slippage if min_dy not set
            min_out = int(min_dy) if min_dy and int(min_dy) > 0 else int(expected_dy * 9950 // 10000)

            tx = pool.functions.exchange(from_index, to_index, dx, min_out).build_transaction({
                "from": account.address,
                "nonce": nonce,
                "gas": 200000,
                "gasPrice": gas_price
            })
            signed = account.sign_transaction(tx)
            tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
            receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=180)

            # Compute actual slippage vs expected
            slippage = 0
            if expected_dy > 0:
                slippage = max(0, int((expected_dy - min_out) * 10000 // expected_dy))

            {
                "amount_in": str(dx),
                "amount_out": str(min_out),
                "expected_dy": str(expected_dy),
                "slippage_bps": slippage,
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
        amount_in: result["amount_in"],
        amount_out: result["amount_out"],
        slippage_bps: result["slippage_bps"],
        tx_hash: result["tx_hash"],
        gas_used: result["gas_used"],
        status: result["status"]
      }}
    end
  end
end
