defmodule Lux.Defi.PancakeSwap.Autocompounder do
  @moduledoc """
  Auto-compounding strategy engine for PancakeSwap yield farms:
  - Plans harvest and swap routing
  - Splits harvested CAKE into LP token pairs
  - Mints additional LP tokens and re-stakes into MasterChef
  """

  @doc """
  Generates an auto-compounding execution plan.
  """
  @spec plan_autocompound(float(), float(), float(), float(), float()) :: %{
          cake_harvested: float(),
          harvest_value_usd: float(),
          token0_amount: float(),
          token1_amount: float(),
          estimated_new_lp_usd: float(),
          viable?: boolean()
        }
  def plan_autocompound(pending_cake, cake_price_usd, price0_usd, price1_usd, gas_cost_usd \\ 0.50)
      when pending_cake > 0 and cake_price_usd > 0 and price0_usd > 0 and price1_usd > 0 do
    total_val = pending_cake * cake_price_usd
    half_val = total_val / 2.0

    token0_amt = half_val / price0_usd
    token1_amt = half_val / price1_usd

    # Viable if reward value is at least $10.0 to overcome gas and slippage
    viable = total_val >= max(gas_cost_usd * 10.0, 10.0)

    %{
      cake_harvested: Float.round(pending_cake, 4),
      harvest_value_usd: Float.round(total_val, 2),
      token0_amount: Float.round(token0_amt, 4),
      token1_amount: Float.round(token1_amt, 4),
      estimated_new_lp_usd: Float.round(total_val, 2),
      viable?: viable
    }
  end

  def plan_autocompound(_, _, _, _, _) do
    %{
      cake_harvested: 0.0,
      harvest_value_usd: 0.0,
      token0_amount: 0.0,
      token1_amount: 0.0,
      estimated_new_lp_usd: 0.0,
      viable?: false
    }
  end
end
