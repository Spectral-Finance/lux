defmodule Lux.Integrations.Curve.Stablecoin do
  @moduledoc """
  Curve Finance stablecoin pool planning and analytics helpers.

  This module does not submit transactions, approve tokens, or touch private
  keys. It normalizes pool/position data, builds gauge action plans, estimates
  CRV rewards, scores pools, checks slippage, and recommends rebalances so live
  adapters can execute only after a separate signing policy approves them.
  """

  @doc """
  Normalizes a Curve pool position.
  """
  @spec normalize_position(map()) :: map()
  def normalize_position(attrs) when is_map(attrs) do
    %{
      pool: string(value(attrs, :pool) || value(attrs, :pool_address)),
      gauge: optional_string(value(attrs, :gauge) || value(attrs, :gauge_address)),
      lp_token: optional_string(value(attrs, :lp_token)),
      lp_balance: number(value(attrs, :lp_balance) || value(attrs, :lp_tokens)),
      staked_balance: number(value(attrs, :staked_balance) || value(attrs, :gauge_staked)),
      share_value_usd: number(value(attrs, :share_value_usd) || value(attrs, :value_usd)),
      base_apr: number(value(attrs, :base_apr)),
      crv_apr: number(value(attrs, :crv_apr)),
      rewards: normalize_rewards(value(attrs, :rewards) || []),
      coins: normalize_coins(value(attrs, :coins) || value(attrs, :balances) || [])
    }
  end

  @doc """
  Builds a pool position summary.
  """
  @spec position_summary([map()]) :: map()
  def position_summary(positions) when is_list(positions) do
    normalized = Enum.map(positions, &normalize_position/1)

    %{
      position_count: length(normalized),
      total_value_usd: normalized |> Enum.map(& &1.share_value_usd) |> Enum.sum() |> round_float(),
      total_lp_balance: normalized |> Enum.map(& &1.lp_balance) |> Enum.sum() |> round_float(),
      total_staked_balance: normalized |> Enum.map(& &1.staked_balance) |> Enum.sum() |> round_float(),
      weighted_apr: weighted_apr(normalized),
      rewards: aggregate_rewards(normalized),
      positions: normalized
    }
  end

  @doc """
  Builds a safe gauge action plan.
  """
  @spec gauge_plan(:stake | :unstake | :claim_rewards, map()) :: {:ok, map()} | {:error, String.t()}
  def gauge_plan(action, attrs) when action in [:stake, :unstake, :claim_rewards] and is_map(attrs) do
    gauge = optional_string(value(attrs, :gauge) || value(attrs, :gauge_address))
    amount = number(value(attrs, :amount))

    cond do
      is_nil(gauge) ->
        {:error, "Curve gauge action requires gauge address"}

      action in [:stake, :unstake] and amount <= 0 ->
        {:error, "Curve gauge stake/unstake amount must be positive"}

      true ->
        {:ok,
         %{
           protocol: :curve,
           action: action,
           gauge: gauge,
           amount: if(action == :claim_rewards, do: nil, else: amount),
           lp_token: optional_string(value(attrs, :lp_token)),
           user: optional_string(value(attrs, :user)),
           requires_signature?: true,
           side_effect_free?: false
         }
         |> reject_nil_values()}
    end
  end

  @doc """
  Estimates CRV reward value and APR contribution.
  """
  @spec reward_projection(map()) :: map()
  def reward_projection(attrs) when is_map(attrs) do
    staked = number(value(attrs, :staked_value_usd) || value(attrs, :value_usd))
    crv_per_day = number(value(attrs, :crv_per_day))
    crv_price = number(value(attrs, :crv_price_usd) || value(attrs, :crv_price))
    multiplier = number(value(attrs, :boost_multiplier) || 1)
    annual_value = crv_per_day * crv_price * multiplier * 365

    %{
      staked_value_usd: staked,
      daily_crv: crv_per_day,
      crv_price_usd: crv_price,
      boost_multiplier: multiplier,
      annual_reward_value_usd: round_float(annual_value),
      crv_apr: if(staked > 0, do: ratio(annual_value, staked), else: 0.0)
    }
  end

  @doc """
  Scores pools for stablecoin allocation.
  """
  @spec pool_analysis([map()], map()) :: map()
  def pool_analysis(pools, opts \\ %{}) when is_list(pools) do
    min_tvl = number(value(opts, :min_tvl_usd))

    scored =
      pools
      |> Enum.map(&normalize_pool/1)
      |> Enum.filter(&(&1.tvl_usd >= min_tvl))
      |> Enum.map(&score_pool/1)
      |> Enum.sort_by(& &1.score, :desc)

    %{
      pool_count: length(scored),
      best_pool: List.first(scored),
      pools: scored
    }
  end

  @doc """
  Checks whether a swap/deposit/withdraw slippage estimate is inside policy.
  """
  @spec slippage_check(map(), map()) :: map()
  def slippage_check(attrs, policy \\ %{}) do
    expected = number(value(attrs, :expected_amount) || value(attrs, :expected))
    minimum = number(value(attrs, :minimum_amount) || value(attrs, :minimum))
    max_bps = number(value(policy, :max_slippage_bps) || 30)
    slippage_bps = if expected > 0, do: ratio(expected - minimum, expected) * 10_000, else: 0.0

    %{
      expected_amount: expected,
      minimum_amount: minimum,
      slippage_bps: round_float(slippage_bps),
      max_slippage_bps: max_bps,
      allowed?: slippage_bps <= max_bps
    }
  end

  @doc """
  Recommends value moves to bring positions closer to target weights.
  """
  @spec rebalance_plan([map()], map(), map()) :: map()
  def rebalance_plan(positions, target_weights, opts \\ %{})
      when is_list(positions) and is_map(target_weights) do
    normalized = Enum.map(positions, &normalize_position/1)
    total = normalized |> Enum.map(& &1.share_value_usd) |> Enum.sum()
    threshold = number(value(opts, :threshold_usd) || 0)

    rows =
      Enum.map(normalized, fn position ->
        target_weight = number(Map.get(target_weights, position.pool) || Map.get(target_weights, String.to_atom(position.pool)))
        current_weight = if total > 0, do: position.share_value_usd / total, else: 0.0
        target_value = total * target_weight

        %{
          pool: position.pool,
          current_value_usd: position.share_value_usd,
          current_weight: round_float(current_weight),
          target_weight: round_float(target_weight),
          target_value_usd: round_float(target_value),
          delta_usd: round_float(target_value - position.share_value_usd)
        }
      end)

    moves =
      rows
      |> Enum.filter(&(abs(&1.delta_usd) > threshold))
      |> Enum.map(fn row ->
        %{
          pool: row.pool,
          action: if(row.delta_usd > 0, do: :add_liquidity, else: :remove_liquidity),
          amount_usd: row.delta_usd |> abs() |> round_float()
        }
      end)

    %{
      total_value_usd: round_float(total),
      threshold_usd: threshold,
      rows: rows,
      moves: moves,
      requires_signature?: moves != []
    }
  end

  @doc """
  Produces a combined yield and risk report.
  """
  @spec yield_report(map()) :: map()
  def yield_report(attrs) when is_map(attrs) do
    positions = position_summary(value(attrs, :positions) || [])
    pools = pool_analysis(value(attrs, :pools) || [], value(attrs, :pool_policy) || %{})

    %{
      positions: positions,
      pools: pools,
      current_weighted_apr: positions.weighted_apr,
      best_available_apr: best_available_apr(pools.pools),
      estimated_annual_yield_usd: positions.total_value_usd * positions.weighted_apr |> round_float()
    }
  end

  defp normalize_pool(attrs) when is_map(attrs) do
    %{
      pool: string(value(attrs, :pool) || value(attrs, :pool_address) || value(attrs, :name)),
      name: string(value(attrs, :name) || value(attrs, :pool)),
      tvl_usd: number(value(attrs, :tvl_usd) || value(attrs, :tvl)),
      base_apr: number(value(attrs, :base_apr)),
      crv_apr: number(value(attrs, :crv_apr)),
      volume_24h_usd: number(value(attrs, :volume_24h_usd) || value(attrs, :volume_24h)),
      virtual_price: number(value(attrs, :virtual_price) || 1),
      imbalance_bps: number(value(attrs, :imbalance_bps)),
      coins: normalize_coins(value(attrs, :coins) || [])
    }
  end

  defp score_pool(pool) do
    total_apr = pool.base_apr + pool.crv_apr
    liquidity_score = :math.log10(max(pool.tvl_usd, 1)) / 10
    volume_score = :math.log10(max(pool.volume_24h_usd, 1)) / 10
    imbalance_penalty = pool.imbalance_bps / 10_000
    score = total_apr + liquidity_score + volume_score - imbalance_penalty

    Map.merge(pool, %{
      total_apr: round_float(total_apr),
      score: round_float(score),
      risk_flags: risk_flags(pool)
    })
  end

  defp risk_flags(pool) do
    []
    |> maybe_flag(pool.tvl_usd < 1_000_000, :low_liquidity)
    |> maybe_flag(pool.imbalance_bps > 150, :pool_imbalance)
    |> maybe_flag(pool.virtual_price <= 0, :bad_virtual_price)
  end

  defp maybe_flag(flags, true, flag), do: [flag | flags]
  defp maybe_flag(flags, false, _flag), do: flags

  defp weighted_apr([]), do: 0.0

  defp weighted_apr(positions) do
    total = positions |> Enum.map(& &1.share_value_usd) |> Enum.sum()

    if total > 0 do
      positions
      |> Enum.map(&(&1.share_value_usd / total * (&1.base_apr + &1.crv_apr)))
      |> Enum.sum()
      |> round_float()
    else
      0.0
    end
  end

  defp aggregate_rewards(positions) do
    positions
    |> Enum.flat_map(& &1.rewards)
    |> Enum.group_by(& &1.token)
    |> Map.new(fn {token, rewards} ->
      {token, rewards |> Enum.map(& &1.amount) |> Enum.sum() |> round_float()}
    end)
  end

  defp normalize_rewards(rewards) when is_list(rewards) do
    Enum.map(rewards, fn reward ->
      %{
        token: string(value(reward, :token)) |> String.upcase(),
        amount: number(value(reward, :amount))
      }
    end)
  end

  defp normalize_rewards(_rewards), do: []

  defp normalize_coins(coins) when is_list(coins) do
    Enum.map(coins, fn
      %{symbol: symbol, balance: balance} -> %{symbol: string(symbol) |> String.upcase(), balance: number(balance)}
      %{"symbol" => symbol, "balance" => balance} -> %{symbol: string(symbol) |> String.upcase(), balance: number(balance)}
      symbol when is_binary(symbol) -> %{symbol: String.upcase(symbol), balance: 0.0}
      other -> %{symbol: string(other) |> String.upcase(), balance: 0.0}
    end)
  end

  defp normalize_coins(_coins), do: []

  defp best_available_apr([]), do: 0.0
  defp best_available_apr(pools), do: pools |> Enum.map(& &1.total_apr) |> Enum.max() |> round_float()

  defp reject_nil_values(map) do
    Map.reject(map, fn {_key, value} -> is_nil(value) end)
  end

  defp optional_string(nil), do: nil
  defp optional_string(""), do: nil
  defp optional_string(value), do: string(value)

  defp string(nil), do: ""
  defp string(value) when is_binary(value), do: value
  defp string(value) when is_atom(value), do: Atom.to_string(value)
  defp string(value), do: to_string(value)

  defp value(map, key) when is_map(map), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))
  defp value(_map, _key), do: nil

  defp number(nil), do: 0.0
  defp number(value) when is_integer(value), do: value * 1.0
  defp number(value) when is_float(value), do: value

  defp number(value) when is_binary(value) do
    case Float.parse(value) do
      {number, _rest} -> number
      :error -> 0.0
    end
  end

  defp number(_value), do: 0.0

  defp ratio(_numerator, 0), do: 0.0
  defp ratio(numerator, denominator), do: Float.round(numerator / denominator, 6)

  defp round_float(value), do: Float.round(number(value), 6)
end
