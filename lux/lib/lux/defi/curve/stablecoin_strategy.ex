defmodule Lux.Defi.Curve.StablecoinStrategy do
  @moduledoc """
  Pure planning helpers for Curve stablecoin pool management.

  The module turns pool, gauge, reward and portfolio snapshots into a
  deterministic ranking/rebalance plan. It deliberately performs no RPC calls
  and signs no transactions; callers can use the output to decide whether to
  deposit, withdraw, stake LP tokens, claim CRV, or rebalance positions through
  their own execution layer.

  This is a safe first integration layer for Curve because it covers the
  decision surface before any on-chain side effects are introduced.
  """

  @default_weights %{
    base_apy: 1.0,
    crv_apy: 1.0,
    volume_apy: 1.0,
    slippage: -1.0,
    imbalance: -0.7,
    utilization: 0.2
  }

  @type pool :: map()
  @type holding :: map()

  @doc """
  Scores and ranks candidate Curve stablecoin pools.

  Expected pool keys may be atoms or strings:

    * `:name` / `"name"`
    * `:base_apy`, `:crv_apy`, `:volume_apy`
    * `:slippage_bps`
    * `:balances` - token balance list used to estimate pool imbalance
    * `:gauge_working_supply`, `:gauge_total_supply` - optional utilization inputs

  Options:

    * `:weights` - partial weight override
    * `:min_tvl_usd` - excludes smaller pools when `:tvl_usd` exists
    * `:max_slippage_bps` - excludes pools with excessive slippage
  """
  @spec rank_pools([pool()], keyword()) :: [map()]
  def rank_pools(pools, opts \\ []) when is_list(pools) do
    weights = Map.merge(@default_weights, Map.new(Keyword.get(opts, :weights, [])))
    min_tvl_usd = Keyword.get(opts, :min_tvl_usd, 0)
    max_slippage_bps = Keyword.get(opts, :max_slippage_bps, 10_000)

    pools
    |> Enum.filter(&(number(&1, :tvl_usd, min_tvl_usd) >= min_tvl_usd))
    |> Enum.filter(&(number(&1, :slippage_bps, 0) <= max_slippage_bps))
    |> Enum.map(&score_pool(&1, weights))
    |> Enum.sort_by(& &1.score, :desc)
  end

  @doc """
  Builds a rebalance plan from current holdings toward the top ranked pools.

  The result is an instruction map for downstream executors. It does not submit
  transactions or require gas. `target_allocation_pct` defaults to equal weight
  across the selected pools.
  """
  @spec rebalance_plan([holding()], [pool()], keyword()) :: map()
  def rebalance_plan(holdings, candidate_pools, opts \\ []) do
    total_value = Enum.reduce(holdings, 0.0, &(&2 + number(&1, :value_usd, 0)))
    target_pool_count = Keyword.get(opts, :target_pool_count, 3)

    targets =
      candidate_pools
      |> rank_pools(opts)
      |> Enum.take(target_pool_count)

    allocation_pct = Keyword.get(opts, :target_allocation_pct, equal_weight(targets))

    target_positions =
      Enum.map(targets, fn ranked ->
        %{
          pool: ranked.name,
          target_pct: allocation_pct,
          target_value_usd: Float.round(total_value * allocation_pct, 2),
          rationale: ranked.rationale
        }
      end)

    %{
      total_value_usd: Float.round(total_value, 2),
      target_positions: target_positions,
      actions: diff_positions(holdings, target_positions),
      requires_signature: false,
      requires_gas: false
    }
  end

  @doc """
  Summarizes claimable CRV rewards across gauges.
  """
  @spec rewards_summary([map()]) :: map()
  def rewards_summary(gauges) when is_list(gauges) do
    total_crv = Enum.reduce(gauges, 0.0, &(&2 + number(&1, :claimable_crv, 0)))
    total_usd = Enum.reduce(gauges, 0.0, &(&2 + number(&1, :claimable_usd, 0)))

    %{
      claimable_crv: Float.round(total_crv, 8),
      claimable_usd: Float.round(total_usd, 2),
      gauges: Enum.map(gauges, &Map.take(normalize_keys(&1), [:name, :claimable_crv, :claimable_usd])),
      requires_signature: false,
      requires_gas: false
    }
  end

  defp score_pool(pool, weights) do
    imbalance = imbalance_ratio(value(pool, :balances, []))
    utilization = utilization_ratio(pool)
    slippage_bps = number(pool, :slippage_bps, 0)

    gross_apy =
      number(pool, :base_apy, 0) * weights.base_apy +
        number(pool, :crv_apy, 0) * weights.crv_apy +
        number(pool, :volume_apy, 0) * weights.volume_apy

    penalty =
      slippage_bps / 100 * abs(weights.slippage) +
        imbalance * 100 * abs(weights.imbalance)

    score = gross_apy - penalty + utilization * 100 * weights.utilization

    %{
      name: value(pool, :name, "unknown"),
      score: Float.round(score, 4),
      gross_apy: Float.round(gross_apy, 4),
      slippage_bps: slippage_bps,
      imbalance_ratio: Float.round(imbalance, 6),
      utilization_ratio: Float.round(utilization, 6),
      rationale: [
        "gross_apy=#{Float.round(gross_apy, 4)}",
        "slippage_bps=#{slippage_bps}",
        "imbalance=#{Float.round(imbalance, 4)}",
        "utilization=#{Float.round(utilization, 4)}"
      ]
    }
  end

  defp diff_positions(holdings, targets) do
    current_by_pool = Map.new(holdings, fn h -> {value(h, :pool, value(h, :name, "unknown")), number(h, :value_usd, 0)} end)

    Enum.map(targets, fn target ->
      current = Map.get(current_by_pool, target.pool, 0.0)
      delta = Float.round(target.target_value_usd - current, 2)

      %{
        pool: target.pool,
        action: cond do
          delta > 0 -> :deposit
          delta < 0 -> :withdraw
          true -> :hold
        end,
        delta_usd: abs(delta)
      }
    end)
  end

  defp equal_weight([]), do: 0.0
  defp equal_weight(targets), do: Float.round(1.0 / length(targets), 6)

  defp imbalance_ratio([]), do: 0.0

  defp imbalance_ratio(balances) when is_list(balances) do
    numeric = Enum.map(balances, &to_float/1)
    total = Enum.sum(numeric)

    if total == 0 do
      0.0
    else
      expected = total / length(numeric)
      max_deviation = numeric |> Enum.map(&abs(&1 - expected)) |> Enum.max(fn -> 0.0 end)
      max_deviation / total
    end
  end

  defp imbalance_ratio(_), do: 0.0

  defp utilization_ratio(pool) do
    working = number(pool, :gauge_working_supply, 0)
    total = number(pool, :gauge_total_supply, 0)

    if total > 0, do: working / total, else: 0.0
  end

  defp number(map, key, default), do: value(map, key, default) |> to_float()

  defp value(map, key, default) when is_map(map) do
    Map.get(map, key, Map.get(map, Atom.to_string(key), default))
  end

  defp value(_, _, default), do: default

  defp normalize_keys(map) do
    Enum.reduce(map, %{}, fn {key, val}, acc ->
      atom_key = if is_atom(key), do: key, else: String.to_atom(to_string(key))
      Map.put(acc, atom_key, val)
    end)
  end

  defp to_float(value) when is_float(value), do: value
  defp to_float(value) when is_integer(value), do: value * 1.0

  defp to_float(value) when is_binary(value) do
    case Float.parse(value) do
      {parsed, _} -> parsed
      :error -> 0.0
    end
  end

  defp to_float(_), do: 0.0
end
