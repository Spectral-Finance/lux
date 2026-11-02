defmodule Lux.Defi.UniswapV3.YieldOptimizer do
  @moduledoc """
  Yield optimization and auto-compounding for Uniswap V3 positions:
  - Annualized fee APR and APY estimation
  - Auto-compounding reinvestment calculations
  - Token ratio re-balancing for reinvesting collected fees
  """

  @doc """
  Calculates annualized fee APR and APY for a position.
  """
  @spec calculate_yield(number(), number(), number(), non_neg_integer()) :: %{
          apr_pct: float(),
          apy_pct: float(),
          daily_yield_usd: float(),
          annual_projected_usd: float()
        }
  def calculate_yield(position_value_usd, pool_daily_volume_usd, pool_fee_tier, compound_freq_per_year \\ 365)
      when position_value_usd > 0 and pool_daily_volume_usd >= 0 do
    fee_rate = pool_fee_tier / 1_000_000.0
    daily_pool_fees = pool_daily_volume_usd * fee_rate

    # Assuming a typical concentrated liquidity share of 0.1% or proportional
    # For a normalized $10,000 position in a $10M pool:
    share_of_pool = position_value_usd / max(pool_daily_volume_usd * 2.0, 1.0)
    daily_position_fees = daily_pool_fees * share_of_pool

    apr = daily_position_fees * 365.0 / position_value_usd
    n = max(compound_freq_per_year, 1)
    apy = :math.pow(1.0 + apr / n, n) - 1.0

    %{
      apr_pct: Float.round(apr * 100.0, 2),
      apy_pct: Float.round(apy * 100.0, 2),
      daily_yield_usd: Float.round(daily_position_fees, 2),
      annual_projected_usd: Float.round(daily_position_fees * 365.0, 2)
    }
  end

  def calculate_yield(_, _, _, _), do: %{apr_pct: 0.0, apy_pct: 0.0, daily_yield_usd: 0.0, annual_projected_usd: 0.0}

  @doc """
  Plans the optimal auto-compounding re-investment of collected fees.
  Calculates required token swap to align with target deposit ratio.
  """
  @spec plan_reinvestment(non_neg_integer(), non_neg_integer(), float(), number(), number()) :: %{
          reinvest0: non_neg_integer(),
          reinvest1: non_neg_integer(),
          swap_required: boolean(),
          swap_direction: :token0_to_token1 | :token1_to_token0 | :none,
          swap_amount: non_neg_integer()
        }
  def plan_reinvestment(collected0, collected1, target_ratio, _price0_usd, _price1_usd) do
    # target_ratio = amount0 / amount1 required by range
    current_ratio = if collected1 > 0, do: collected0 / collected1, else: 1.0

    cond do
      abs(current_ratio - target_ratio) < 0.05 ->
        %{
          reinvest0: collected0,
          reinvest1: collected1,
          swap_required: false,
          swap_direction: :none,
          swap_amount: 0
        }

      current_ratio > target_ratio ->
        # Excess token0, need to swap portion of token0 to token1
        excess0 = round((collected0 - collected1 * target_ratio) / 2.0)
        %{
          reinvest0: collected0 - excess0,
          reinvest1: collected1,
          swap_required: true,
          swap_direction: :token0_to_token1,
          swap_amount: max(excess0, 0)
        }

      true ->
        # Excess token1, need to swap portion of token1 to token0
        excess1 = round((collected1 - collected0 / max(target_ratio, 0.0001)) / 2.0)
        %{
          reinvest0: collected0,
          reinvest1: collected1 - excess1,
          swap_required: true,
          swap_direction: :token1_to_token0,
          swap_amount: max(excess1, 0)
        }
    end
  end
end
