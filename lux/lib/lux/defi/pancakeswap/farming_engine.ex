defmodule Lux.Defi.PancakeSwap.FarmingEngine do
  @moduledoc """
  Yield farming optimization and APY calculation engine for PancakeSwap:
  - Trading fee APR and CAKE emission farming APR estimation
  - Auto-compounded APY projection
  - Harvest viability evaluation based on gas costs
  """

  @seconds_per_year 31_536_000

  @doc """
  Calculates total APR and APY for a PancakeSwap farming pool.
  """
  @spec calculate_pool_apy(float(), float(), float(), float(), pos_integer(), pos_integer(), float()) :: %{
          fee_apr_pct: float(),
          farming_apr_pct: float(),
          total_apr_pct: float(),
          compounded_apy_pct: float()
        }
  def calculate_pool_apy(tvl_usd, daily_vol_usd, pool_fee_rate, cake_per_sec, alloc_point, total_alloc, cake_price_usd)
      when tvl_usd > 0 and total_alloc > 0 do
    # 1. Trading Fee APR
    daily_fees = daily_vol_usd * pool_fee_rate
    fee_apr = daily_fees * 365.0 / tvl_usd * 100.0

    # 2. Farming CAKE APR
    pool_cake_per_sec = cake_per_sec * (alloc_point / total_alloc)
    annual_cake = pool_cake_per_sec * @seconds_per_year
    annual_cake_value_usd = annual_cake * cake_price_usd
    farming_apr = annual_cake_value_usd / tvl_usd * 100.0

    total_apr = fee_apr + farming_apr

    # 3. Compounded APY assuming daily compounding (n = 365)
    r = total_apr / 100.0
    compounded_apy = (:math.pow(1.0 + r / 365.0, 365) - 1.0) * 100.0

    %{
      fee_apr_pct: Float.round(fee_apr, 2),
      farming_apr_pct: Float.round(farming_apr, 2),
      total_apr_pct: Float.round(total_apr, 2),
      compounded_apy_pct: Float.round(compounded_apy, 2)
    }
  end

  def calculate_pool_apy(_, _, _, _, _, _, _), do: %{fee_apr_pct: 0.0, farming_apr_pct: 0.0, total_apr_pct: 0.0, compounded_apy_pct: 0.0}

  @doc """
  Checks if pending CAKE rewards are sufficient to justify harvest gas expenses.
  """
  @spec harvest_profitable?(float(), float(), float()) :: {:ok, boolean(), float()}
  def harvest_profitable?(pending_cake, cake_price_usd, gas_cost_usd \\ 0.50) do
    reward_value_usd = Float.round(pending_cake * cake_price_usd, 2)
    # Profitable if reward exceeds 5x the gas cost
    profitable = reward_value_usd >= gas_cost_usd * 5.0
    {:ok, profitable, reward_value_usd}
  end
end
