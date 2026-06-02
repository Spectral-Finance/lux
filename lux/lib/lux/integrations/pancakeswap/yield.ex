defmodule Lux.Integrations.PancakeSwap.Yield do
  @moduledoc """
  Yield farming automation and analysis for PancakeSwap.

  Implements position tracking, auto-compounding simulation,
  reward calculation, and risk assessment for farming strategies.
  """

  require Logger

  alias Lux.Integrations.PancakeSwap.{Pools, Client}

  @typedoc "Yield farming position"
  @type position :: %{
          required(:pool_id) => String.t() | non_neg_integer(),
          required(:staked_amount) => float(),
          optional(:chain_id) => non_neg_integer(),
          optional(:entry_price) => float(),
          optional(:timestamp) => DateTime.t()
        }

  @doc """
  Tracks a yield farming position and returns estimated metrics.

  ## Options
  - `:pool_id` - Pool ID (required)
  - `:staked_amount` - Amount staked in pool tokens (required)
  - `:chain_id` - Chain ID (default from config)
  - `:entry_price` - Entry price for the position
  - `:stake_token` - Token symbol of the stake token
  """
  @spec track_position(keyword()) :: {:ok, map()} | {:error, String.t()}
  def track_position(opts) do
    pool_id = Keyword.fetch!(opts, :pool_id)
    staked_amount = Keyword.fetch!(opts, :staked_amount)
    chain_id = Keyword.get(opts, :chain_id, 56)

    with {:ok, pool} <- Pools.get_pool(pool_id, chain_id: chain_id) do
      apy = Pools.calculate_apy(pool)
      daily_rate = apy / 100.0 / 365.0

      daily_yield = staked_amount * daily_rate / 100.0
      weekly_yield = daily_yield * 7
      monthly_yield = daily_yield * 30
      yearly_yield = daily_yield * 365

      {:ok, %{
        pool_id: "#{pool_id}",
        pair: pool["pair"],
        chain_id: chain_id,
        staked_amount: staked_amount,
        current_apy: Float.round(apy, 2),
        estimated_daily_yield: Float.round(daily_yield, 6),
        estimated_weekly_yield: Float.round(weekly_yield, 6),
        estimated_monthly_yield: Float.round(monthly_yield, 6),
        estimated_yearly_yield: Float.round(yearly_yield, 6),
        tvl_usd: pool["tvl_usd"],
        volume_24h: pool["volume_usd"],
        fee_tier: pool["fee_tier"],
        risk_score: assess_risk_score(pool),
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      }}
    end
  end

  @doc """
  Calculates estimated rewards for a position over a given time horizon.

  ## Options
  - `:pool_id` - Pool ID
  - `:staked_amount` - Amount staked
  - `:days` - Time horizon in days (default: 30)
  - `:compound_frequency` - `:daily`, `:weekly`, or `:none` (default: :daily)
  """
  @spec calculate_rewards(keyword()) :: {:ok, map()} | {:error, String.t()}
  def calculate_rewards(opts) do
    pool_id = Keyword.fetch!(opts, :pool_id)
    staked_amount = Keyword.fetch!(opts, :staked_amount)
    days = Keyword.get(opts, :days, 30)
    compound_freq = Keyword.get(opts, :compound_frequency, :daily)
    chain_id = Keyword.get(opts, :chain_id, 56)

    with {:ok, pool} <- Pools.get_pool(pool_id, chain_id: chain_id) do
      apy = Pools.calculate_apy(pool)
      compound_periods = compound_periods(days, compound_freq)
      compound_rate = apy / 100.0 / compound_periods

      final_amount =
        case compound_freq do
          :none ->
            staked_amount + (staked_amount * apy / 100.0 * days / 365.0)

          _ ->
            staked_amount * :math.pow(1 + compound_rate, compound_periods)
        end

      rewards = final_amount - staked_amount

      {:ok, %{
        pool_id: "#{pool_id}",
        pair: pool["pair"],
        staked_amount: staked_amount,
        apy: Float.round(apy, 2),
        time_horizon_days: days,
        compound_frequency: compound_freq,
        compound_periods: compound_periods,
        estimated_rewards: Float.round(rewards, 6),
        estimated_final_amount: Float.round(final_amount, 6),
        roi_pct: Float.round((rewards / staked_amount) * 100.0, 2)
      }}
    end
  end

  @doc """
  Simulates auto-compounding returns over a configurable time period.

  ## Options
  - `:pool_id` - Pool ID
  - `:principal` - Initial investment amount
  - `:days` - Simulation period in days (default: 365)
  - `:compound_frequency` - `:daily`, `:weekly`, or `:monthly` (default: :daily)
  - `:reinvest_rewards` - Whether to reinvest all rewards (default: true)
  """
  @spec simulate_auto_compound(keyword()) :: {:ok, map()} | {:error, String.t()}
  def simulate_auto_compound(opts) do
    pool_id = Keyword.fetch!(opts, :pool_id)
    principal = Keyword.fetch!(opts, :principal)
    days = Keyword.get(opts, :days, 365)
    compound_freq = Keyword.get(opts, :compound_frequency, :daily)
    chain_id = Keyword.get(opts, :chain_id, 56)

    with {:ok, pool} <- Pools.get_pool(pool_id, chain_id: chain_id) do
      apy = Pools.calculate_apy(pool)
      periods = compound_periods(days, compound_freq)
      period_rate = apy / 100.0 / periods

      final_amount = principal * :math.pow(1 + period_rate, periods)
      total_yield = final_amount - principal
      average_monthly_yield = total_yield / (days / 30.0)

      projections =
        1..min(12, days |> Kernel./(30) |> ceil())
        |> Enum.map(fn month ->
          month_days = min(month * 30, days)
          month_periods = compound_periods(month_days, compound_freq)
          month_amount = principal * :math.pow(1 + period_rate, month_periods)

          %{
            month: month,
            estimated_value: Float.round(month_amount, 2),
            cumulative_yield: Float.round(month_amount - principal, 2)
          }
        end)

      {:ok, %{
        pool_id: "#{pool_id}",
        pair: pool["pair"],
        apy: Float.round(apy, 2),
        principal: principal,
        days: days,
        compound_frequency: compound_freq,
        compound_periods: periods,
        final_amount: Float.round(final_amount, 2),
        total_yield: Float.round(total_yield, 2),
        roi_pct: Float.round((total_yield / principal) * 100.0, 2),
        average_monthly_yield: Float.round(average_monthly_yield, 2),
        risk_score: assess_risk_score(pool),
        projections: projections
      }}
    end
  end

  @doc """
  Lists top yield farming opportunities ranked by APY.

  ## Options
  - `:chain_id` - Chain ID
  - `:limit` - Maximum farms to return (default: 20)
  - `:min_tvl` - Minimum TVL in USD (default: 50000)
  - `:max_risk_score` - Maximum acceptable risk score (default: 8)
  """
  @spec top_farms(keyword()) :: {:ok, [map()]} | {:error, String.t()}
  def top_farms(opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    min_tvl = Keyword.get(opts, :min_tvl, 50_000)
    max_risk_score = Keyword.get(opts, :max_risk_score, 8)

    with {:ok, pools} <- Pools.list_pools(Keyword.take(opts, [:chain_id, :limit])) do
      ranked =
        pools
        |> Enum.filter(&(Map.get(&1, "tvl_usd", 0) >= min_tvl))
        |> Enum.map(fn pool ->
          risk = assess_risk_score(pool)

          pool
          |> Map.put("risk_score", risk)
          |> Map.put("risk_label", risk_label(risk))
        end)
        |> Enum.filter(&(Map.get(&1, "risk_score", 10) <= max_risk_score))
        |> Enum.sort_by(& &1["apy"], :desc)
        |> Enum.take(limit)
        |> Enum.map(fn pool ->
          %{
            pool_id: pool["id"],
            pair: pool["pair"],
            apy: Float.round(pool["apy"], 2),
            tvl_usd: pool["tvl_usd"],
            volume_24h: pool["volume_usd"],
            fee_tier: pool["fee_tier"],
            risk_score: pool["risk_score"],
            risk_label: pool["risk_label"],
            chain_id: pool["chain_id"]
          }
        end)

      {:ok, ranked}
    end
  end

  @doc """
  Assesses the risk level for a farming pool.

  Returns a risk assessment with scores across multiple dimensions.

  ## Options
  - `:include_details` - Include detailed breakdown (default: true)
  """
  @spec assess_risk(String.t() | non_neg_integer(), keyword()) ::
          {:ok, map()} | {:error, String.t()}
  def assess_risk(pool_id, opts \\ []) do
    include_details = Keyword.get(opts, :include_details, true)

    with {:ok, pool} <- Pools.get_pool(pool_id) do
      score = assess_risk_score(pool)

      assessment = %{
        pool_id: "#{pool_id}",
        pair: pool["pair"],
        overall_risk_score: score,
        risk_level: risk_label(score),
        tvl_usd: pool["tvl_usd"],
        volume_24h: pool["volume_usd"],
        fee_tier: pool["fee_tier"]
      }

      assessment =
        if include_details do
          Map.merge(assessment, %{
            details: %{
              liquidity_risk: liquidity_risk(pool),
              volatility_risk: volatility_risk(pool),
              concentration_risk: concentration_risk(pool),
              protocol_risk: protocol_risk(pool),
              impermanent_loss_risk: impermanent_loss_risk(pool)
            },
            recommendations: risk_recommendations(score)
          })
        else
          assessment
        end

      {:ok, assessment}
    end
  end

  defp assess_risk_score(pool) do
    lr = liquidity_risk(pool)
    vr = volatility_risk(pool)
    cr = concentration_risk(pool)
    pr = protocol_risk(pool)
    ilr = impermanent_loss_risk(pool)

    Float.round((lr * 2.5 + vr * 2.0 + cr * 1.5 + pr * 2.0 + ilr * 2.0) / 10.0, 1)
  end

  defp liquidity_risk(pool) do
    tvl = Map.get(pool, "tvl_usd", 0.0)

    cond do
      tvl > 10_000_000 -> 1
      tvl > 1_000_000 -> 3
      tvl > 100_000 -> 5
      tvl > 10_000 -> 7
      true -> 9
    end
  end

  defp volatility_risk(pool) do
    volume = Map.get(pool, "volume_usd", 0.0)
    tvl = Map.get(pool, "tvl_usd", 1.0)
    ratio = volume / tvl

    cond do
      ratio > 5.0 -> 8
      ratio > 2.0 -> 6
      ratio > 1.0 -> 4
      ratio > 0.5 -> 2
      true -> 1
    end
  end

  defp concentration_risk(pool) do
    fee_tier_pct = Map.get(pool, "fee_tier_pct", 0.0025)

    cond do
      fee_tier_pct >= 0.01 -> 2
      fee_tier_pct >= 0.005 -> 3
      fee_tier_pct >= 0.0025 -> 5
      fee_tier_pct >= 0.0005 -> 7
      true -> 9
    end
  end

  defp protocol_risk(_pool), do: 3

  defp impermanent_loss_risk(pool) do
    fee_tier_pct = Map.get(pool, "fee_tier_pct", 0.0025)

    cond do
      fee_tier_pct >= 0.01 -> 2
      fee_tier_pct >= 0.005 -> 4
      fee_tier_pct >= 0.0025 -> 6
      true -> 8
    end
  end

  defp risk_label(score) when score <= 2, do: :very_low
  defp risk_label(score) when score <= 4, do: :low
  defp risk_label(score) when score <= 6, do: :moderate
  defp risk_label(score) when score <= 8, do: :high
  defp risk_label(_), do: :very_high

  defp risk_recommendations(score) when score <= 3 do
    ["Suitable for conservative yield farming",
     "Consider larger position allocation",
     "Good entry for long-term holding"]
  end

  defp risk_recommendations(score) when score <= 6 do
    ["Moderate risk — standard yield farming",
     "Monitor pool performance weekly",
     "Consider position size relative to portfolio"]
  end

  defp risk_recommendations(_) do
    ["High risk — speculative yield farming",
     "Limit position size to 5% of portfolio",
     "Monitor daily for changes in TVL and volume",
     "Set stop-loss if available"]
  end

  defp compound_periods(days, :daily), do: days
  defp compound_periods(days, :weekly), do: div(days, 7) |> max(1)
  defp compound_periods(days, :monthly), do: div(days, 30) |> max(1)
  defp compound_periods(days, _), do: days
end
