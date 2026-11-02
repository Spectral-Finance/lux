defmodule Lux.Defi.Curve.YieldOptimizer do
  @moduledoc """
  Yield maximization and auto-compounding for Curve Finance stablecoin positions:
  - Combines swap fee base APY with boosted CRV gauge rewards
  - Models veCRV boost effect (1.0x to 2.5x)
  - Generates auto-compounding reinvestment plans
  """

  @doc """
  Calculates the comprehensive APY for a Curve gauge position.
  """
  @spec calculate_total_apy(float(), float(), float(), float()) :: %{
          base_apy_pct: float(),
          reward_apy_pct: float(),
          boost: float(),
          total_apy_pct: float(),
          annual_projected_usd: float()
        }
  def calculate_total_apy(base_apy, base_crv_apy, boost \\ 1.0, position_value_usd \\ 10000.0) do
    effective_boost = min(max(boost, 1.0), 2.5)
    boosted_crv_apy = base_crv_apy * effective_boost
    total_apy = base_apy + boosted_crv_apy
    annual_yield = position_value_usd * (total_apy / 100.0)

    %{
      base_apy_pct: Float.round(base_apy, 2),
      reward_apy_pct: Float.round(boosted_crv_apy, 2),
      boost: Float.round(effective_boost, 2),
      total_apy_pct: Float.round(total_apy, 2),
      annual_projected_usd: Float.round(annual_yield, 2)
    }
  end

  @doc """
  Plans the optimal auto-compounding harvesting route.
  """
  @spec plan_autocompound(float(), float(), String.t()) :: %{
          crv_amount: float(),
          target_coin: String.t(),
          estimated_lp_return: float(),
          viable?: boolean()
        }
  def plan_autocompound(unclaimed_crv, crv_price_usd, target_coin \\ "USDC") do
    harvest_value_usd = unclaimed_crv * crv_price_usd
    # Viable if claimed value exceeds $20 (sufficient to offset gas)
    viable = harvest_value_usd >= 20.0

    %{
      crv_amount: unclaimed_crv,
      target_coin: target_coin,
      estimated_lp_return: Float.round(harvest_value_usd, 2),
      viable?: viable
    }
  end
end
