defmodule Lux.Prisms.Curve.StablecoinPoolPrism do
  @moduledoc """
  Curve Finance Stablecoin Pool Management, Gauge Boost & Yield Optimization Prism (#81).

  Implements:
  - Curve StableSwap amplification invariant (`D`) and output (`get_dy`) calculation
  - Gauge staking boost (`1.0x` to `2.5x` via `veCRV` voting escrow share)
  - CRV + external incentive APR aggregation and optimal pool selection
  - Automated stablecoin pool rebalancing when token weights or peg ratios drift
  """

  @fee_bps_default 4.0

  defmodule PoolState do
    @moduledoc "Curve StableSwap pool state."
    defstruct [
      :pool_id,
      :name,
      :coins,
      :balances,
      amp: 200,
      fee_bps: 4.0,
      base_apy: 0.0,
      crv_apr_min: 0.0,
      crv_apr_max: 0.0,
      extra_rewards_apr: 0.0,
      virtual_price: 1.0
    ]
  end

  defmodule GaugePosition do
    @moduledoc "Curve Liquidity Gauge user staking position."
    defstruct [
      :pool_id,
      :lp_staked,
      :pool_total_lp,
      :user_vecrv,
      :total_vecrv
    ]
  end

  @doc """
  Computes the Curve StableSwap invariant `D` via Newton-Raphson iteration for an `n`-coin pool
  with amplification coefficient `amp`.
  """
  @spec compute_d([number()], pos_integer()) :: {:ok, float()} | {:error, atom()}
  def compute_d(balances, amp) when is_list(balances) and length(balances) >= 2 and amp > 0 do
    if Enum.any?(balances, &(&1 <= 0)) do
      {:error, :invalid_balances}
    else
      n = length(balances)
      sum_x = Enum.sum(balances) * 1.0
      ann = amp * :math.pow(n, n)

      d_final =
        Enum.reduce_while(1..64, sum_x, fn _iter, d ->
          d_p =
            Enum.reduce(balances, d, fn x, acc ->
              acc * d / (x * n)
            end)

          prev_d = d
          numerator = (ann * sum_x + d_p * n) * d
          denominator = (ann - 1.0) * d + (n + 1.0) * d_p
          next_d = numerator / denominator

          if abs(next_d - prev_d) <= 1.0e-6 do
            {:halt, next_d}
          else
            {:cont, next_d}
          end
        end)

      {:ok, Float.round(d_final, 6)}
    end
  end

  def compute_d(_, _), do: {:error, :invalid_parameters}

  @doc """
  Estimates a stablecoin swap output (`dy`), effective exchange rate, and slippage in basis points
  using the Curve StableSwap invariant.
  """
  @spec estimate_swap(%PoolState{}, non_neg_integer(), non_neg_integer(), number()) ::
          {:ok, map()} | {:error, atom()}
  def estimate_swap(%PoolState{} = pool, i, j, dx)
      when is_integer(i) and is_integer(j) and i != j and is_number(dx) and dx > 0 do
    n = length(pool.balances || [])

    if i < 0 or j < 0 or i >= n or j >= n do
      {:error, :invalid_coin_index}
    else
      with {:ok, d} <- compute_d(pool.balances, pool.amp) do
        ann = pool.amp * :math.pow(n, n)
        x_new = Enum.at(pool.balances, i) + dx

        other_balances =
          pool.balances
          |> Enum.with_index()
          |> Enum.reject(fn {_bal, idx} -> idx == j end)
          |> Enum.map(fn {bal, idx} -> if idx == i, do: x_new, else: bal * 1.0 end)

        s_prime = Enum.sum(other_balances)

        c =
          Enum.reduce(other_balances, d, fn x_val, acc ->
            acc * d / (x_val * n)
          end)
          |> Kernel.*(d / (ann * n))

        b = s_prime + d / ann

        y_final =
          Enum.reduce_while(1..64, d, fn _iter, y ->
            prev_y = y
            next_y = (y * y + c) / (2.0 * y + b - d)

            if abs(next_y - prev_y) <= 1.0e-6 do
              {:halt, next_y}
            else
              {:cont, next_y}
            end
          end)

        y_old = Enum.at(pool.balances, j) * 1.0
        dy_gross = max(0.0, y_old - y_final)
        fee_rate = (pool.fee_bps || @fee_bps_default) / 10_000.0
        fee_amount = dy_gross * fee_rate
        dy_net = dy_gross - fee_amount
        effective_rate = dy_net / dx
        slippage_bps = max(0.0, (1.0 - effective_rate) * 10_000.0)

        {:ok,
         %{
           pool_id: pool.pool_id,
           coin_in: Enum.at(pool.coins, i),
           coin_out: Enum.at(pool.coins, j),
           dx: Float.round(dx * 1.0, 6),
           dy_gross: Float.round(dy_gross, 6),
           fee_amount: Float.round(fee_amount, 6),
           dy_net: Float.round(dy_net, 6),
           effective_rate: Float.round(effective_rate, 6),
           slippage_bps: Float.round(slippage_bps, 4)
         }}
      end
    end
  end

  def estimate_swap(_, _, _, _), do: {:error, :invalid_swap}

  @doc """
  Computes the Curve Gauge staking boost factor (`1.0x` to `2.5x`) and effective total APY
  given a user's `GaugePosition` and `PoolState`.
  """
  @spec evaluate_gauge_yield(%PoolState{}, %GaugePosition{}) :: {:ok, map()} | {:error, atom()}
  def evaluate_gauge_yield(%PoolState{} = pool, %GaugePosition{} = pos) do
    cond do
      pos.lp_staked <= 0 or pos.pool_total_lp <= 0 ->
        {:error, :invalid_lp_position}

      pos.user_vecrv < 0 or pos.total_vecrv <= 0 ->
        {:error, :invalid_vecrv}

      true ->
        working_base = 0.4 * pos.lp_staked
        vecrv_share = pos.user_vecrv / pos.total_vecrv
        working_bonus = 0.6 * pos.pool_total_lp * vecrv_share
        working_balance = min(pos.lp_staked * 1.0, working_base + working_bonus)
        boost_factor = working_balance / working_base

        boosted_crv_apr =
          pool.crv_apr_min +
            (pool.crv_apr_max - pool.crv_apr_min) * ((boost_factor - 1.0) / 1.5)

        total_apy = pool.base_apy + boosted_crv_apr + pool.extra_rewards_apr

        {:ok,
         %{
           pool_id: pool.pool_id,
           working_balance: Float.round(working_balance, 4),
           boost_factor: Float.round(boost_factor, 4),
           boosted_crv_apr: Float.round(boosted_crv_apr, 4),
           total_apy: Float.round(total_apy, 4)
         }}
    end
  end

  @doc """
  Ranks candidate Curve stablecoin pools by risk-adjusted boosted APY and selects the optimal allocation.
  """
  @spec plan_rebalance([{%PoolState{}, %GaugePosition{}}], float()) :: {:ok, map()}
  def plan_rebalance(candidates, current_apy_pct \\ 0.0) when is_list(candidates) do
    scored =
      candidates
      |> Enum.flat_map(fn {pool, pos} ->
        case evaluate_gauge_yield(pool, pos) do
          {:ok, metrics} ->
            total_liq = Enum.sum(pool.balances) * 1.0
            max_bal = Enum.max(pool.balances) * 1.0
            imbalance_ratio = max_bal / (total_liq / length(pool.balances))
            penalty = max(0.0, (imbalance_ratio - 1.15) * 5.0)
            score = metrics.total_apy - penalty

            [
              Map.merge(metrics, %{
                name: pool.name,
                imbalance_ratio: Float.round(imbalance_ratio, 4),
                risk_adjusted_apy: Float.round(score, 4)
              })
            ]

          _ ->
            []
        end
      end)
      |> Enum.sort_by(& &1.risk_adjusted_apy, :desc)

    best = List.first(scored)
    should_rebalance = best != nil and best.risk_adjusted_apy - current_apy_pct >= 0.50

    {:ok,
     %{
       recommended_pool: best && best.pool_id,
       should_rebalance: should_rebalance,
       expected_apy_gain:
         if(best, do: Float.round(best.risk_adjusted_apy - current_apy_pct, 4), else: 0.0),
       rankings: scored
     }}
  end
end
