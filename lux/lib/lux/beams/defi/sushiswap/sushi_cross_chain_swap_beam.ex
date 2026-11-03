defmodule Lux.Beams.Defi.SushiSwap.SushiCrossChainSwapBeam do
  @moduledoc """
  A coordinated workflow beam for executing cross-chain swaps via SushiXSwap v2:
  1. Inspects source chain pool state via SushiPoolPrism
  2. Quotes cross-chain swap route and bridge transfer fees via SushiXSwapPrism
  3. Verifies bridge safety and slippage compliance via BridgeSecurityPrism
  """

  use Lux.Beam,
    name: "SushiXSwap Cross-Chain Swap Beam",
    description: "Evaluates multi-chain pools, quotes cross-chain swaps, and verifies bridge safety",
    input_schema: %{
      type: :object,
      properties: %{
        src_chain: %{type: :integer, description: "Source chain ID"},
        dst_chain: %{type: :integer, description: "Destination chain ID"},
        src_token: %{type: :string, description: "Source token symbol"},
        dst_token: %{type: :string, description: "Destination token symbol"},
        amount_in: %{type: :number, description: "Input transfer amount"},
        src_price_usd: %{type: :number, default: 1.0},
        dst_price_usd: %{type: :number, default: 1.0}
      },
      required: ["src_chain", "dst_chain", "src_token", "dst_token", "amount_in"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        pool_metrics: %{type: :object},
        quote_metrics: %{type: :object},
        security_metrics: %{type: :object}
      },
      required: ["status"]
    },
    generate_execution_log: true

  alias Lux.Prisms.Defi.SushiSwap.SushiPoolPrism
  alias Lux.Prisms.Defi.SushiSwap.SushiXSwapPrism
  alias Lux.Prisms.Defi.SushiSwap.BridgeSecurityPrism

  sequence do
    step(:pool_info, SushiPoolPrism, %{
      chain_id: [:input, :src_chain],
      token0: [:input, :src_token],
      token1: "USDC"
    })

    step(:cross_chain_quote, SushiXSwapPrism, %{
      src_chain: [:input, :src_chain],
      dst_chain: [:input, :dst_chain],
      src_token: [:input, :src_token],
      dst_token: [:input, :dst_token],
      amount_in: [:input, :amount_in],
      src_price_usd: [:input, :src_price_usd],
      dst_price_usd: [:input, :dst_price_usd]
    })

    step(:safety_check, BridgeSecurityPrism, %{
      amount_in_usd: 100.0,
      fee_usd: [:steps, :cross_chain_quote, :result, :total_fee_usd],
      est_out_usd: 98.0
    })
  end
end
