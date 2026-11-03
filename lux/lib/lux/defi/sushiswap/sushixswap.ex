defmodule Lux.Defi.SushiSwap.SushiXSwap do
  @moduledoc """
  SushiXSwap cross-chain bridge and swap routing engine:
  - Multi-hop source swap, Stargate cross-chain bridge, and destination swap
  - Calculates bridge transfer fees, gas relayer compensation, and minimum amounts out
  """

  @bridge_costs %{
    # {src_chain, dst_chain} => %{base_fee_usd: float, fee_bps: int, est_minutes: int}
    {1, 42161} => %{base_fee_usd: 6.0, fee_bps: 6, est_minutes: 10},
    {42161, 1} => %{base_fee_usd: 8.0, fee_bps: 6, est_minutes: 12},
    {42161, 137} => %{base_fee_usd: 1.5, fee_bps: 4, est_minutes: 3},
    {137, 42161} => %{base_fee_usd: 1.5, fee_bps: 4, est_minutes: 3},
    {8453, 42161} => %{base_fee_usd: 1.0, fee_bps: 4, est_minutes: 2},
    {42161, 8453} => %{base_fee_usd: 1.0, fee_bps: 4, est_minutes: 2}
  }

  @doc """
  Quotes cross-chain swap route from src_chain to dst_chain.
  """
  @spec quote_cross_chain_swap(pos_integer(), pos_integer(), String.t(), String.t(), float(), float(), float()) ::
          {:ok, map()} | {:error, term()}
  def quote_cross_chain_swap(src_chain, dst_chain, src_token, dst_token, amount_in, src_price_usd, dst_price_usd) do
    if src_chain == dst_chain do
      {:error, :same_chain_route}
    else
      cost_cfg = Map.get(@bridge_costs, {src_chain, dst_chain}, %{base_fee_usd: 3.0, fee_bps: 5, est_minutes: 5})

      gross_usd = amount_in * src_price_usd
      bridge_pct_fee = gross_usd * (cost_cfg.fee_bps / 10000.0)
      total_fee_usd = Float.round(cost_cfg.base_fee_usd + bridge_pct_fee, 2)

      net_usd = max(gross_usd - total_fee_usd, 0.0)
      estimated_amount_out = if dst_price_usd > 0, do: Float.round(net_usd / dst_price_usd, 4), else: 0.0

      # 0.5% default max slippage
      min_amount_out = Float.round(estimated_amount_out * 0.995, 4)

      {:ok,
       %{
         src_chain: src_chain,
         dst_chain: dst_chain,
         src_token: String.upcase(src_token),
         dst_token: String.upcase(dst_token),
         amount_in: amount_in,
         estimated_amount_out: estimated_amount_out,
         min_amount_out: min_amount_out,
         total_fee_usd: total_fee_usd,
         estimated_minutes: cost_cfg.est_minutes,
         protocol: "SushiXSwap v2 (Stargate/LayerZero)"
       }}
    end
  end
end
