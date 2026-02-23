defmodule Lux.Prisms.UniswapV3.UniswapV3CollectFeesPrism do
  @moduledoc """
  A prism for collecting accumulated trading fees from a Uniswap V3 position.

  Harvests all accrued trading fees from an NFT position without removing the
  underlying liquidity. Fees are sent directly to the caller's address.

  ## Example

      iex> Lux.Prisms.UniswapV3.UniswapV3CollectFeesPrism.run(%{
      ...>   token_id: 123456
      ...> })
      {:ok, %{
        token_id: 123456,
        fees0_collected: "12345678",
        fees1_collected: "9876543210000000",
        tx_hash: "0xabc...",
        gas_used: 180000,
        status: "success"
      }}

  The prism reads authentication from config:
  - :uniswap_v3_private_key — Ethereum private key for signing
  - :uniswap_v3_rpc_url — Ethereum JSON-RPC endpoint URL
  """

  use Lux.Prism,
    name: "Uniswap V3 Collect Fees",
    description: "Collects accumulated trading fees from a Uniswap V3 position without removing liquidity",
    input_schema: %{
      type: :object,
      properties: %{
        token_id: %{
          type: :integer,
          description: "NFT token ID of the position to collect fees from"
        },
        recipient: %{
          type: :string,
          description: "Address to receive the collected fees (defaults to caller)",
          pattern: "^0x[a-fA-F0-9]{40}$"
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
        token_id: %{type: :integer, description: "NFT token ID"},
        fees0_collected: %{type: :string, description: "Token0 fees collected (in wei)"},
        fees1_collected: %{type: :string, description: "Token1 fees collected (in wei)"},
        tx_hash: %{type: :string, description: "Transaction hash"},
        gas_used: %{type: :integer, description: "Gas consumed"},
        status: %{type: :string, description: "Operation result"}
      },
      required: ["token_id", "fees0_collected", "fees1_collected", "tx_hash", "status"]
    }

  import Lux.Python
  alias Lux.Config
  require Lux.Python
  require Logger

  @default_position_manager "0xC36442b4a4522E871399CD717aBDD847Ab11FE88"
  @default_rpc "https://eth.llamarpc.com"

  def handler(%{token_id: token_id} = input, _ctx) do
    position_manager = Map.get(input, :position_manager_address, @default_position_manager)
    recipient = Map.get(input, :recipient, nil)

    Logger.info("Uniswap V3 collect fees: tokenId=#{token_id}")

    with {:ok, private_key} <- get_config(:uniswap_v3_private_key, "UNISWAP_V3_PRIVATE_KEY"),
         {:ok, rpc_url} <- {:ok, get_rpc_url()},
         {:ok, result} <- collect_fees(rpc_url, private_key, position_manager, token_id, recipient) do
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

  defp collect_fees(rpc_url, private_key, position_manager, token_id, recipient) do
    result =
      python variables: %{
               rpc_url: rpc_url,
               private_key: private_key,
               position_manager: position_manager,
               token_id: token_id,
               recipient_override: recipient
             } do
        ~PY"""
        from web3 import Web3
        from eth_account import Account

        POSITION_MANAGER_ABI = [
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
            ]},
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
            ]}
        ]

        MAX_UINT128 = (2**128) - 1

        try:
            w3 = Web3(Web3.HTTPProvider(rpc_url))
            account = Account.from_key(private_key)
            pm = Web3.to_checksum_address(position_manager)
            tid = int(token_id)
            rec = Web3.to_checksum_address(recipient_override) if recipient_override else account.address

            pm_contract = w3.eth.contract(address=pm, abi=POSITION_MANAGER_ABI)

            # Check owed amounts before collecting
            pos = pm_contract.functions.positions(tid).call()
            tokens_owed0 = pos[10]
            tokens_owed1 = pos[11]

            nonce = w3.eth.get_transaction_count(account.address)
            gas_price = w3.eth.gas_price

            # Collect max possible fees
            collect_params = (tid, rec, MAX_UINT128, MAX_UINT128)
            col_tx = pm_contract.functions.collect(collect_params).build_transaction({
                "from": account.address, "nonce": nonce,
                "gas": 200000, "gasPrice": gas_price
            })
            signed = account.sign_transaction(col_tx)
            col_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
            receipt = w3.eth.wait_for_transaction_receipt(col_hash, timeout=180)

            fees0 = str(tokens_owed0)
            fees1 = str(tokens_owed1)

            COLLECT_TOPIC = "0x70935338e69775456a85ddef226c395fb668b63fa0115f5f20610b388e6ca9c0"
            for log in receipt.logs:
                if len(log.topics) > 0 and log.topics[0].hex() == COLLECT_TOPIC:
                    raw = log.data.hex() if isinstance(log.data, bytes) else log.data.replace("0x", "")
                    data_bytes = bytes.fromhex(raw.replace("0x", ""))
                    if len(data_bytes) >= 64:
                        fees0 = str(int.from_bytes(data_bytes[0:32], "big"))
                        fees1 = str(int.from_bytes(data_bytes[32:64], "big"))
                    break

            {
                "token_id": tid,
                "fees0_collected": fees0,
                "fees1_collected": fees1,
                "tx_hash": col_hash.hex(),
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
        token_id: result["token_id"],
        fees0_collected: result["fees0_collected"],
        fees1_collected: result["fees1_collected"],
        tx_hash: result["tx_hash"],
        gas_used: result["gas_used"],
        status: result["status"]
      }}
    end
  end
end
