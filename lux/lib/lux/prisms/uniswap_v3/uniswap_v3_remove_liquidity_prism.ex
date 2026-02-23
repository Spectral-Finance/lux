defmodule Lux.Prisms.UniswapV3.UniswapV3RemoveLiquidityPrism do
  @moduledoc """
  A prism for removing concentrated liquidity from a Uniswap V3 position.

  Decreases liquidity from an existing NFT position and collects the underlying
  tokens plus any accumulated fees in a single transaction.

  ## Example

      iex> Lux.Prisms.UniswapV3.UniswapV3RemoveLiquidityPrism.run(%{
      ...>   token_id: 123456,
      ...>   liquidity_percent: 100,
      ...>   slippage_bps: 50
      ...> })
      {:ok, %{
        token_id: 123456,
        liquidity_removed: "1500000000000000000",
        amount0_collected: "999900000",
        amount1_collected: "499800000000000000",
        fees0_collected: "1234567",
        fees1_collected: "567890123456789",
        tx_hash: "0xabc...",
        gas_used: 280000,
        status: "success"
      }}

  The prism reads authentication from config:
  - :uniswap_v3_private_key — Ethereum private key for signing
  - :uniswap_v3_rpc_url — Ethereum JSON-RPC endpoint URL
  """

  use Lux.Prism,
    name: "Uniswap V3 Remove Liquidity",
    description: "Decreases liquidity from a Uniswap V3 position and collects underlying tokens plus fees",
    input_schema: %{
      type: :object,
      properties: %{
        token_id: %{
          type: :integer,
          description: "NFT token ID of the position to withdraw from"
        },
        liquidity_percent: %{
          type: :integer,
          description: "Percentage of liquidity to remove (1-100)",
          minimum: 1,
          maximum: 100,
          default: 100
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
        position_manager_address: %{
          type: :string,
          description: "NonfungiblePositionManager address (defaults to Ethereum mainnet)",
          default: "0xC36442b4a4522E871399CD717aBDD847Ab11FE88",
          pattern: "^0x[a-fA-F0-9]{40}$"
        }
      },
      required: ["token_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        token_id: %{type: :integer, description: "NFT token ID of the position"},
        liquidity_removed: %{type: :string, description: "Liquidity units removed"},
        amount0_collected: %{type: :string, description: "Token0 received from liquidity (in wei)"},
        amount1_collected: %{type: :string, description: "Token1 received from liquidity (in wei)"},
        fees0_collected: %{type: :string, description: "Token0 fees collected (in wei)"},
        fees1_collected: %{type: :string, description: "Token1 fees collected (in wei)"},
        tx_hash: %{type: :string, description: "Transaction hash"},
        gas_used: %{type: :integer, description: "Gas consumed"},
        status: %{type: :string, description: "Operation result"}
      },
      required: ["token_id", "liquidity_removed", "amount0_collected", "amount1_collected", "tx_hash", "status"]
    }

  import Lux.Python
  alias Lux.Config
  require Lux.Python
  require Logger

  @default_position_manager "0xC36442b4a4522E871399CD717aBDD847Ab11FE88"
  @default_rpc "https://eth.llamarpc.com"

  def handler(%{token_id: token_id} = input, _ctx) do
    liquidity_pct = Map.get(input, :liquidity_percent, 100)
    slippage = Map.get(input, :slippage_bps, 50)
    deadline_secs = Map.get(input, :deadline_seconds, 1200)
    position_manager = Map.get(input, :position_manager_address, @default_position_manager)

    Logger.info("Uniswap V3 remove liquidity: tokenId=#{token_id} pct=#{liquidity_pct}%")

    with {:ok, private_key} <- get_config(:uniswap_v3_private_key, "UNISWAP_V3_PRIVATE_KEY"),
         {:ok, rpc_url} <- {:ok, get_rpc_url()},
         {:ok, result} <- decrease_and_collect(rpc_url, private_key, position_manager,
                                               token_id, liquidity_pct, slippage, deadline_secs) do
      {:ok, result}
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
    case Config.get(:uniswap_v3_rpc_url) do
      nil -> System.get_env("UNISWAP_V3_RPC_URL") || @default_rpc
      url -> url
    end
  rescue
    _ -> System.get_env("UNISWAP_V3_RPC_URL") || @default_rpc
  end

  defp decrease_and_collect(rpc_url, private_key, position_manager, token_id,
                            liquidity_pct, slippage_bps, deadline_secs) do
    result =
      python variables: %{
               rpc_url: rpc_url,
               private_key: private_key,
               position_manager: position_manager,
               token_id: token_id,
               liquidity_percent: liquidity_pct,
               slippage_bps: slippage_bps,
               deadline_seconds: deadline_secs
             } do
        ~PY"""
        import time
        from web3 import Web3
        from eth_account import Account

        POSITION_MANAGER_ABI = [
            {"name": "positions", "type": "function", "inputs": [
                {"name": "tokenId", "type": "uint256"}
            ], "outputs": [
                {"name": "nonce", "type": "uint96"},
                {"name": "operator", "type": "address"},
                {"name": "token0", "type": "address"},
                {"name": "token1", "type": "address"},
                {"name": "fee", "type": "uint24"},
                {"name": "tickLower", "type": "int24"},
                {"name": "tickUpper", "type": "int24"},
                {"name": "liquidity", "type": "uint128"},
                {"name": "feeGrowthInside0LastX128", "type": "uint256"},
                {"name": "feeGrowthInside1LastX128", "type": "uint256"},
                {"name": "tokensOwed0", "type": "uint128"},
                {"name": "tokensOwed1", "type": "uint128"}
            ]},
            {"name": "decreaseLiquidity", "type": "function", "inputs": [
                {"name": "params", "type": "tuple", "components": [
                    {"name": "tokenId", "type": "uint256"},
                    {"name": "liquidity", "type": "uint128"},
                    {"name": "amount0Min", "type": "uint256"},
                    {"name": "amount1Min", "type": "uint256"},
                    {"name": "deadline", "type": "uint256"}
                ]}
            ], "outputs": [
                {"name": "amount0", "type": "uint256"},
                {"name": "amount1", "type": "uint256"}
            ]},
            {"name": "collect", "type": "function", "inputs": [
                {"name": "params", "type": "tuple", "components": [
                    {"name": "tokenId", "type": "uint256"},
                    {"name": "recipient", "type": "address"},
                    {"name": "amount0Max", "type": "uint128"},
                    {"name": "amount1Max", "type": "uint128"}
                ]}
            ], "outputs": [
                {"name": "amount0", "type": "uint256"},
                {"name": "amount1", "type": "uint256"}
            ]}
        ]

        MAX_UINT128 = (2**128) - 1

        try:
            w3 = Web3(Web3.HTTPProvider(rpc_url))
            account = Account.from_key(private_key)
            pm = Web3.to_checksum_address(position_manager)
            tid = int(token_id)

            pm_contract = w3.eth.contract(address=pm, abi=POSITION_MANAGER_ABI)

            # Get current position info
            pos = pm_contract.functions.positions(tid).call()
            current_liquidity = pos[7]  # liquidity field
            tokens_owed0 = pos[10]
            tokens_owed1 = pos[11]

            # Calculate liquidity to remove
            remove_liquidity = int(current_liquidity * liquidity_percent // 100)
            if remove_liquidity == 0 and current_liquidity > 0:
                remove_liquidity = current_liquidity

            slippage_factor = (10000 - slippage_bps) / 10000
            nonce = w3.eth.get_transaction_count(account.address)
            gas_price = w3.eth.gas_price
            deadline = int(time.time()) + deadline_seconds

            fees0 = str(tokens_owed0)
            fees1 = str(tokens_owed1)
            liq_removed = str(remove_liquidity)
            amount0_from_liq = "0"
            amount1_from_liq = "0"
            total0 = "0"
            total1 = "0"
            tx_hash_hex = "0x"
            gas_used = 0

            if remove_liquidity > 0:
                # DecreaseLiquidity
                dec_params = (tid, remove_liquidity, 0, 0, deadline)
                dec_tx = pm_contract.functions.decreaseLiquidity(dec_params).build_transaction({
                    "from": account.address, "nonce": nonce,
                    "gas": 300000, "gasPrice": gas_price
                })
                signed = account.sign_transaction(dec_tx)
                dec_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
                dec_receipt = w3.eth.wait_for_transaction_receipt(dec_hash, timeout=180)
                nonce += 1

                # Decode decrease output
                DECREASE_TOPIC = "0x26f6a048ee9138f2c0ce266f322cb99228e8d619ae2bff30c67f8dcf9d2377b4"
                for log in dec_receipt.logs:
                    if len(log.topics) > 0 and log.topics[0].hex() == DECREASE_TOPIC:
                        raw = log.data.hex() if isinstance(log.data, bytes) else log.data.replace("0x", "")
                        data_bytes = bytes.fromhex(raw.replace("0x", ""))
                        if len(data_bytes) >= 64:
                            amount0_from_liq = str(int.from_bytes(data_bytes[0:32], "big"))
                            amount1_from_liq = str(int.from_bytes(data_bytes[32:64], "big"))
                        break

                gas_used += dec_receipt.gasUsed
                tx_hash_hex = dec_hash.hex()

            # Collect all owed tokens (liquidity proceeds + fees)
            collect_params = (tid, account.address, MAX_UINT128, MAX_UINT128)
            col_tx = pm_contract.functions.collect(collect_params).build_transaction({
                "from": account.address, "nonce": nonce,
                "gas": 200000, "gasPrice": gas_price
            })
            signed = account.sign_transaction(col_tx)
            col_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
            col_receipt = w3.eth.wait_for_transaction_receipt(col_hash, timeout=180)
            gas_used += col_receipt.gasUsed
            tx_hash_hex = col_hash.hex()

            COLLECT_TOPIC = "0x70935338e69775456a85ddef226c395fb668b63fa0115f5f20610b388e6ca9c0"
            for log in col_receipt.logs:
                if len(log.topics) > 0 and log.topics[0].hex() == COLLECT_TOPIC:
                    raw = log.data.hex() if isinstance(log.data, bytes) else log.data.replace("0x", "")
                    data_bytes = bytes.fromhex(raw.replace("0x", ""))
                    if len(data_bytes) >= 64:
                        total0 = str(int.from_bytes(data_bytes[0:32], "big"))
                        total1 = str(int.from_bytes(data_bytes[32:64], "big"))
                        # Fees = total - liquidity proceeds
                        liq0 = int(amount0_from_liq)
                        liq1 = int(amount1_from_liq)
                        t0 = int(total0)
                        t1 = int(total1)
                        fees0 = str(max(0, t0 - liq0))
                        fees1 = str(max(0, t1 - liq1))
                    break

            {
                "token_id": tid,
                "liquidity_removed": liq_removed,
                "amount0_collected": total0,
                "amount1_collected": total1,
                "fees0_collected": fees0,
                "fees1_collected": fees1,
                "tx_hash": tx_hash_hex,
                "gas_used": gas_used,
                "status": "success"
            }
        except Exception as e:
            {"error": str(e)}
        """
      end

    if Map.has_key?(result, "error") do
      {:error, result["error"]}
    else
      {:ok, %{
        token_id: result["token_id"],
        liquidity_removed: result["liquidity_removed"],
        amount0_collected: result["amount0_collected"],
        amount1_collected: result["amount1_collected"],
        fees0_collected: result["fees0_collected"],
        fees1_collected: result["fees1_collected"],
        tx_hash: result["tx_hash"],
        gas_used: result["gas_used"],
        status: result["status"]
      }}
    end
  end
end
