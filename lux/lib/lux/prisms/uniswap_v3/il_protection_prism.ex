defmodule Lux.Prisms.UniswapV3.IlProtectionPrism do
  @moduledoc """
  A prism that computes concentrated liquidity Impermanent Loss (IL) vs a HODL
  benchmark, net LP return after fees, and delta-neutral hedge sizing.
  """

  use Lux.Prism,
    name: "Uniswap V3 Impermanent Loss Protection",
    description: "Calculates concentrated liquidity Impermanent Loss and recommends delta hedges",
    input_schema: %{
      type: :object,
      properties: %{
        entry_price: %{type: :number},
        current_price: %{type: :number},
        lower_price: %{type: :number},
        upper_price: %{type: :number},
        initial_amount0: %{type: :number},
        initial_amount1: %{type: :number},
        accrued_fees_usd: %{type: :number},
        max_il_pct_threshold: %{type: :number}
      },
      required: ["entry_price", "current_price", "lower_price", "upper_price", "initial_amount0", "initial_amount1"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        hodl_value_usd: %{type: :number},
        lp_position_value_usd: %{type: :number},
        impermanent_loss_usd: %{type: :number},
        impermanent_loss_pct: %{type: :number},
        net_pnl_vs_hodl_usd: %{type: :number},
        hedge_required: %{type: :boolean},
        recommended_short_delta_token0: %{type: :number}
      },
      required: ["hodl_value_usd", "lp_position_value_usd", "impermanent_loss_pct", "hedge_required"]
    }

  alias Lux.Prisms.UniswapV3.PositionManagerPrism

  def handler(input, _ctx) do
    p_entry = Map.fetch!(input, :entry_price)
    p_curr = Map.fetch!(input, :current_price)
    pa = Map.fetch!(input, :lower_price)
    pb = Map.fetch!(input, :upper_price)
    init0 = Map.fetch!(input, :initial_amount0)
    init1 = Map.fetch!(input, :initial_amount1)
    fees_usd = Map.get(input, :accrued_fees_usd, 0.0)
    max_il_pct = Map.get(input, :max_il_pct_threshold, 3.0)

    l = PositionManagerPrism.liquidity_for_amounts(p_entry, pa, pb, init0, init1)
    {entry0, entry1} = PositionManagerPrism.amounts_for_liquidity(p_entry, pa, pb, l)
    {curr0, curr1} = PositionManagerPrism.amounts_for_liquidity(p_curr, pa, pb, l)

    hodl_val = entry0 * p_curr + entry1
    lp_val = curr0 * p_curr + curr1
    il_usd = max(hodl_val - lp_val, 0.0)
    il_pct = if hodl_val > 0, do: Float.round(il_usd / hodl_val * 100.0, 4), else: 0.0
    net_vs_hodl = Float.round(lp_val + fees_usd - hodl_val, 4)

    delta_mismatch = curr0 - entry0
    hedge_required = il_pct >= max_il_pct

    {:ok,
     %{
       hodl_value_usd: Float.round(hodl_val, 4),
       lp_position_value_usd: Float.round(lp_val, 4),
       impermanent_loss_usd: Float.round(il_usd, 4),
       impermanent_loss_pct: il_pct,
       net_pnl_vs_hodl_usd: net_vs_hodl,
       hedge_required: hedge_required,
       recommended_short_delta_token0: Float.round(max(delta_mismatch, 0.0), 6)
     }}
  end
end
