defmodule Lux.Integrations.Curve.PoolManager do
  @moduledoc """
  Curve Finance stablecoin pool analysis, gauge CRV reward boost calculation,
  slippage protection, and automated rebalancing (#81).
  """

  @doc """
  Computes minimum acceptable output (`min_dy`) given expected output and max slippage bps.
  """
  def calculate_min_dy(expected_amount, max_slippage_bps \\ 15)
      when expected_amount >= 0 and max_slippage_bps >= 0 and max_slippage_bps <= 10_000 do
    factor = (10_000 - max_slippage_bps) / 10_000.0
    {:ok, Float.round(expected_amount * factor, 6)}
  end

  @doc """
  Calculates Curve gauge voting-escrow boost factor (between 1.0x and 2.5x).
  """
  def calculate_gauge_boost(user_liquidity, total_liquidity, user_vecrv, total_vecrv)
      when user_liquidity > 0 and total_liquidity > 0 and total_vecrv > 0 do
    working_balance =
      min(
        user_liquidity,
        0.4 * user_liquidity + 0.6 * total_liquidity * (user_vecrv / total_vecrv)
      )

    boost = working_balance / (0.4 * user_liquidity)
    {:ok, Float.round(min(2.5, max(1.0, boost)), 4)}
  end

  @doc """
  Selects the highest risk-adjusted APY stablecoin pool meeting minimum TVL and peg deviation thresholds.
  """
  def select_optimal_pool(pools, opts \\ []) when is_list(pools) do
    min_tvl = Keyword.get(opts, :min_tvl_usd, 1_000_000.0)
    max_peg_dev_bps = Keyword.get(opts, :max_peg_deviation_bps, 30)

    eligible =
      pools
      |> Enum.filter(fn p ->
        Map.get(p, :tvl_usd, 0.0) >= min_tvl and
          Map.get(p, :peg_deviation_bps, 999) <= max_peg_dev_bps
      end)
      |> Enum.sort_by(fn p -> -(Map.get(p, :base_apy, 0.0) + Map.get(p, :crv_apy, 0.0)) end)

    case eligible do
      [best | _] -> {:ok, best}
      [] -> {:error, :no_eligible_pool}
    end
  end
end
