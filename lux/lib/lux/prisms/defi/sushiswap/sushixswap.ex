defmodule Lux.Prisms.Defi.SushiSwap.SushiXSwapPrism do
  @moduledoc """
  Quotes cross-chain swaps using SushiXSwap v2 with Stargate / LayerZero bridge integration.
  """

  use Lux.Prism,
    name: "SushiXSwap Cross-Chain Quote",
    description: "Calculates cross-chain swap outputs, bridge fees, and minimum received amounts",
    input_schema: %{
      type: :object,
      properties: %{
        src_chain: %{type: :integer, description: "Source chain ID"},
        dst_chain: %{type: :integer, description: "Destination chain ID"},
        src_token: %{type: :string, description: "Source token symbol"},
        dst_token: %{type: :string, description: "Destination token symbol"},
        amount_in: %{type: :number, description: "Input token amount"},
        src_price_usd: %{type: :number, default: 1.0},
        dst_price_usd: %{type: :number, default: 1.0}
      },
      required: ["src_chain", "dst_chain", "src_token", "dst_token", "amount_in"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        src_chain: %{type: :integer},
        dst_chain: %{type: :integer},
        src_token: %{type: :string},
        dst_token: %{type: :string},
        estimated_amount_out: %{type: :number},
        min_amount_out: %{type: :number},
        total_fee_usd: %{type: :number}
      },
      required: ["src_chain", "dst_chain", "estimated_amount_out", "min_amount_out"]
    }

  alias Lux.Defi.SushiSwap.SushiXSwap

  def handler(input, _ctx) do
    src_chain = Map.get(input, :src_chain) || Map.get(input, "src_chain")
    dst_chain = Map.get(input, :dst_chain) || Map.get(input, "dst_chain")
    src_token = Map.get(input, :src_token) || Map.get(input, "src_token")
    dst_token = Map.get(input, :dst_token) || Map.get(input, "dst_token")
    amt_in = (Map.get(input, :amount_in) || Map.get(input, "amount_in", 0.0)) * 1.0
    src_px = (Map.get(input, :src_price_usd) || Map.get(input, "src_price_usd", 1.0)) * 1.0
    dst_px = (Map.get(input, :dst_price_usd) || Map.get(input, "dst_price_usd", 1.0)) * 1.0

    SushiXSwap.quote_cross_chain_swap(src_chain, dst_chain, src_token, dst_token, amt_in, src_px, dst_px)
  end
end
