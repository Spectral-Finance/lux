defmodule Lux.Beams.UniswapV3.LiquidityManagementBeam do
  @moduledoc """
  An end-to-end Beam that orchestrates automated Uniswap V3 liquidity management:
  1. Reads pool state & volatility via `PoolMonitorLens`
  2. Computes optimal concentrated tick bounds & rebalance decision via `RangeOptimizerPrism`
  3. Evaluates Impermanent Loss & delta hedge sizing via `IlProtectionPrism`
  4. Evaluates fee harvesting & auto-compounding via `FeeCollectorPrism`
  5. Executes position mint/rebalance via `PositionManagerPrism`
  """

  alias Lux.Lenses.UniswapV3.PoolMonitorLens
  alias Lux.Prisms.UniswapV3.FeeCollectorPrism
  alias Lux.Prisms.UniswapV3.IlProtectionPrism
  alias Lux.Prisms.UniswapV3.PositionManagerPrism
  alias Lux.Prisms.UniswapV3.RangeOptimizerPrism

  @doc """
  Executes the complete Uniswap V3 liquidity management pipeline.
  """
  def run(input) when is_map(input) do
    with {:ok, pool} <- PoolMonitorLens.snapshot(input),
         {:ok, range} <-
           RangeOptimizerPrism.handler(
             %{
               current_price: pool.current_price,
               twap_price: pool.twap_price,
               daily_volatility: pool.daily_volatility,
               horizon_days: Map.get(input, :horizon_days, 7.0),
               confidence_sigma: Map.get(input, :confidence_sigma, 2.0),
               fee_tier: pool.fee_tier,
               existing_lower_price: Map.get(input, :existing_lower_price),
               existing_upper_price: Map.get(input, :existing_upper_price)
             },
             %{}
           ),
         {:ok, fees} <-
           FeeCollectorPrism.handler(
             %{
               tokens_owed0: Map.get(input, :tokens_owed0, 0.05),
               tokens_owed1: Map.get(input, :tokens_owed1, 125.0),
               token0_price_usd: pool.current_price,
               token1_price_usd: 1.0,
               estimated_gas_usd: Map.get(input, :estimated_gas_usd, 1.50),
               auto_compound: Map.get(input, :auto_compound, true)
             },
             %{}
           ),
         {:ok, il} <-
           IlProtectionPrism.handler(
             %{
               entry_price: Map.get(input, :entry_price, pool.twap_price),
               current_price: pool.current_price,
               lower_price: range.optimal_lower_price,
               upper_price: range.optimal_upper_price,
               initial_amount0: Map.get(input, :amount0_desired, 1.0),
               initial_amount1: Map.get(input, :amount1_desired, pool.current_price),
               accrued_fees_usd: fees.total_fees_usd
             },
             %{}
           ),
         action = if(range.should_rebalance, do: "rebalance", else: "mint"),
         {:ok, position} <-
           PositionManagerPrism.handler(
             %{
               action: action,
               pool_address: pool.pool_address,
               fee_tier: pool.fee_tier,
               current_price: pool.current_price,
               lower_price: range.optimal_lower_price,
               upper_price: range.optimal_upper_price,
               amount0_desired: Map.get(input, :amount0_desired, 1.0) + fees.compounded_token0,
               amount1_desired: Map.get(input, :amount1_desired, pool.current_price) + fees.compounded_token1,
               slippage_bps: Map.get(input, :slippage_bps, 50)
             },
             %{}
           ) do
      {:ok,
       %{
         pool: pool,
         range_optimization: range,
         fee_collection: fees,
         il_protection: il,
         position_execution: position
       }}
    end
  end
end
