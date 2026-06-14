defmodule Lux.Prisms.Sushiswap.SushiswapBridgePrism do
  @moduledoc """
  Monitors SushiSwap cross-chain bridge (Stargate) operations.

  ## Example

      iex> Lux.Prisms.Sushiswap.SushiswapBridgePrism.run(%{
      ...>   action: "get_bridge_fee",
      ...>   src_chain_id: 56,
      ...>   dst_chain_id: 137,
      ...>   token: "USDC",
      ...>   amount: "1000000000000000000"
      ...> })
      {:ok, %{status: "success", fee_wei: "...", fee_usd: "..."}}
  """

  use Lux.Prism,
    name: "SushiSwap Bridge Monitor",
    description: "Monitors cross-chain bridge operations and fees via Stargate",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "Action: get_bridge_fee | get_bridge_status | estimate_time",
          enum: ["get_bridge_fee", "get_bridge_status", "estimate_time"]
        },
        src_chain_id: %{type: :integer, description: "Source chain ID"},
        dst_chain_id: %{type: :integer, description: "Destination chain ID"},
        token: %{type: :string, description: "Token symbol: USDC, USDT, ETH"},
        amount: %{type: :string, description: "Amount in wei"},
        tx_hash: %{type: :string, description: "Bridge TX hash (for status check)"}
      },
      required: ["action", "src_chain_id", "dst_chain_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        fee_wei: %{type: :string},
        fee_usd: %{type: :string},
        estimated_time: %{type: :string},
        bridge_status: %{type: :string},
        src_chain: %{type: :string},
        dst_chain: %{type: :string}
      },
      required: ["status"]
    }

  import Lux.Python

  # Official SushiXSwap V2 addresses from github.com/sushiswap/sushixswap-v2
  @sushixswap_v2 "0x804b526e5bf4349819fe2db65349d0825870f8ee"

  # Stargate adapter addresses per chain (official deployments)
  @stargate_adapters %{
    1     => "0xD408a20f1213286fB3158a2bfBf5bFfAca8bF269",  # Ethereum
    56    => "0xFF51a7C624Eb866917102707F3dA8bFb99Db8692",  # BSC
    137   => "0x1719DEf1BF8422a777f2442bcE704AC4Fb20c7f0",  # Polygon
    42_161 => "0xFF51a7C624Eb866917102707F3dA8bFb99Db8692",  # Arbitrum
    10    => "0xA62eC622DbA415Aa94110739B1f951B1202Cf322",  # Optimism
    8453  => "0xD408a20f1213286fB3158a2bfBf5bFfAca8bF269",  # Base
    43_114 => "0xFF51a7C624Eb866917102707F3dA8bFb99Db8692"   # Avalanche
  }

  # Stargate chain IDs (different from EVM chain IDs)
  @stargate_chain_ids %{
    1     => 101,  # Ethereum
    56    => 102,  # BSC
    137   => 109,  # Polygon
    42_161 => 110,  # Arbitrum
    10    => 111,  # Optimism
    8453  => 184,  # Base
    43_114 => 106   # Avalanche
  }

  @rpcs %{
    1     => "https://eth.llamarpc.com",
    56    => "https://bsc-dataseed.binance.org/",
    137   => "https://polygon-rpc.com",
    42_161 => "https://arb1.arbitrum.io/rpc",
    10    => "https://mainnet.optimism.io",
    8453  => "https://mainnet.base.org",
    43_114 => "https://api.avax.network/ext/bc/C/rpc"
  }
  require Lux.Python

  @chain_names %{
    1     => "Ethereum",
    56    => "BSC",
    137   => "Polygon",
    42_161 => "Arbitrum",
    10    => "Optimism",
    8453  => "Base",
    43_114 => "Avalanche"
  }

  # Stargate bridge contracts (used by SushiXSwap)
  @stargate_routers %{
    1     => "0x8731d54E9D02c286767d56ac03e8037C07e01e98",
    56    => "0x4a364f8c717cAAD9A442737Eb7b8A55cc6cf18D8",
    137   => "0x45A01E4e04F14f7A4a6702c74187c5F6222033cd",
    42_161 => "0x53Bf833A5d6c4ddA888F69c22C88C9f356a41614"
  }

  def handler(input, _ctx) do
    execute_bridge_action(build_params(input))
  end

  defp build_params(input) do
    src_chain_id = get_field(input, :src_chain_id)
    dst_chain_id = get_field(input, :dst_chain_id)

    %{
      action: get_field(input, :action),
      rpc_url: @rpcs[src_chain_id] || @rpcs[56],
      src_router: @stargate_routers[src_chain_id],
      src_chain_id: src_chain_id,
      dst_chain_id: dst_chain_id,
      token: get_field(input, :token) || "USDC",
      amount: get_field(input, :amount) || "0",
      tx_hash: get_field(input, :tx_hash),
      src_name: @chain_names[src_chain_id] || "Unknown",
      dst_name: @chain_names[dst_chain_id] || "Unknown"
    }
  end

  defp get_field(input, key) do
    input[key] || input[Atom.to_string(key)]
  end

  defp execute_bridge_action(params) do
    result =
      python variables: %{
        action:       params.action,
        rpc_url:      params.rpc_url,
        src_router:   params.src_router,
        src_chain_id: params.src_chain_id,
        dst_chain_id: params.dst_chain_id,
        token:        params.token,
        amount:       params.amount,
        tx_hash:      params.tx_hash,
        src_name:     params.src_name,
        dst_name:     params.dst_name
      } do
        ~PY"""
        from web3 import Web3

        w3 = Web3(Web3.HTTPProvider(rpc_url))

        # Stargate LayerZero chain IDs
        LZ_CHAIN_IDS = {
          1:     101,
          56:    102,
          137:   109,
          42_161: 110,
          10:    111,
          43_114: 106
        }

        # Average bridge times (minutes)
        BRIDGE_TIMES = {
          (1, 56):     "10-20 min",
          (1, 137):    "10-20 min",
          (1, 42_161):  "10-20 min",
          (56, 137):   "10-15 min",
          (56, 42_161): "10-15 min",
          (137, 56):   "10-15 min",
        }

        if action == "get_bridge_fee":
          # Stargate quoteLayerZeroFee ABI
          STARGATE_ABI = [{
            "inputs": [
              {"name": "_dstChainId",    "type": "uint16"},
              {"name": "_functionType",  "type": "uint8"},
              {"name": "_toAddress",     "type": "bytes"},
              {"name": "_transferAndCallPayload", "type": "bytes"},
              {"name": "_lzTxParams",    "type": "tuple",
               "components": [
                 {"name": "dstGasForCall",    "type": "uint256"},
                 {"name": "dstNativeAmount",  "type": "uint256"},
                 {"name": "dstNativeAddr",    "type": "bytes"}
               ]}
            ],
            "name": "quoteLayerZeroFee",
            "outputs": [
              {"name": "", "type": "uint256"},
              {"name": "", "type": "uint256"}
            ],
            "stateMutability": "view",
            "type": "function"
          }]

          try:
            if src_router and w3.is_connected():
              router = w3.eth.contract(
                address=Web3.to_checksum_address(src_router),
                abi=STARGATE_ABI
              )
              lz_dst = LZ_CHAIN_IDS.get(dst_chain_id, 109)
              fee, _ = router.functions.quoteLayerZeroFee(
                lz_dst, 1,
                b"\\x00" * 20,
                b"",
                (0, 0, b"\\x00")
              ).call()
              fee_usd = float(fee) / 1e18 * 300  # rough BNB/ETH price
              {
                "status":     "success",
                "fee_wei":    str(fee),
                "fee_usd":    f"~${fee_usd:.4f}",
                "src_chain":  src_name,
                "dst_chain":  dst_name,
                "token":      token
              }
            else:
              {
                "status":    "success",
                "fee_wei":   "0",
                "fee_usd":   "~$0.10-$0.50 (estimate)",
                "src_chain": src_name,
                "dst_chain": dst_name,
                "note":      "RPC unavailable — showing estimate"
              }
          except Exception as e:
            {
              "status":    "success",
              "fee_wei":   "0",
              "fee_usd":   "~$0.10-$0.50 (estimate)",
              "src_chain": src_name,
              "dst_chain": dst_name,
              "note":      str(e)
            }

        elif action == "estimate_time":
          bridge_time = BRIDGE_TIMES.get(
            (src_chain_id, dst_chain_id),
            "10-30 min"
          )
          {
            "status":         "success",
            "estimated_time": bridge_time,
            "src_chain":      src_name,
            "dst_chain":      dst_name
          }

        elif action == "get_bridge_status":
          if not tx_hash:
            {"error": "tx_hash required for status check"}
          else:
            try:
              receipt = w3.eth.get_transaction_receipt(tx_hash)
              status  = "completed" if receipt.status == 1 else "failed"
              {
                "status":        "success",
                "bridge_status": status,
                "tx_hash":       tx_hash,
                "gas_used":      receipt.gasUsed,
                "src_chain":     src_name,
                "dst_chain":     dst_name
              }
            except Exception as e:
              {"error": f"Could not fetch TX status: {str(e)}"}
        else:
          {"error": f"Unknown action: {action}"}
        """
      end

    case result do
      %{"error" => e}          -> {:error, e}
      %{"status" => "success"} = r -> {:ok, r}
      _ -> {:error, "Unexpected response"}
    end
  end
end
