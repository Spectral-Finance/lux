defmodule Lux.Integrations.CurveFinance.Stablecoins do
  @moduledoc """
  Stablecoin pool analysis, gauge planning, rebalancing, and yield helpers for Curve.
  """

  alias Lux.Integrations.CurveFinance

  @default_policy %{
    min_tvl_usd: 1_000_000.0,
    min_base_apy: 0.0,
    max_slippage_pct: 0.003,
    max_pool_concentration_pct: 0.40,
    target_allocations: %{},
    reward_weight: 0.35,
    volume_weight: 0.20,
    tvl_weight: 0.15,
    slippage_weight: 0.30
  }

  @doc "Normalizes Curve pool API payloads into stable analysis records."
  @spec pools(term()) :: [map()]
  def pools(payload) do
    payload
    |> pool_items()
    |> Enum.map(&normalize_pool/1)
  end

  @doc "Returns Curve pools whose coins look stablecoin-focused."
  @spec stablecoin_pools(term()) :: [map()]
  def stablecoin_pools(payload) do
    payload
    |> pools()
    |> Enum.filter(&stablecoin_pool?/1)
  end

  @doc "Scores and ranks stablecoin pools for allocation."
  @spec pool_analysis(term(), keyword() | map()) :: [map()]
  def pool_analysis(payload, opts \\ []) do
    policy = policy(opts)

    payload
    |> stablecoin_pools()
    |> Enum.map(&score_pool(&1, policy))
    |> Enum.filter(&(&1.tvl_usd >= policy.min_tvl_usd and &1.base_apy >= policy.min_base_apy))
    |> Enum.sort_by(& &1.score, :desc)
  end

  @doc "Builds a gauge staking plan for a pool position."
  @spec gauge_staking_plan(map(), number(), keyword() | map()) ::
          {:ok, map()} | {:error, String.t()}
  def gauge_staking_plan(pool, lp_amount, opts \\ []) do
    normalized = normalize_pool(pool)
    amount = numeric(lp_amount)

    cond do
      amount <= 0 ->
        {:error, "lp amount must be positive"}

      is_nil(normalized.gauge_address) or normalized.gauge_address == "" ->
        {:error, "pool has no gauge"}

      true ->
        {:ok,
         %{
           pool: normalized.name,
           pool_address: normalized.address,
           gauge_address: normalized.gauge_address,
           lp_token_address: normalized.lp_token_address,
           lp_amount: amount,
           action: :stake_lp_tokens,
           auto_claim_rewards: value(opts, :auto_claim_rewards, true),
           expected_reward_tokens: normalized.reward_tokens,
           estimated_apy: normalized.total_apy
         }}
    end
  end

  @doc "Ranks pools by CRV/reward APY and liquidity quality."
  @spec rewards_optimization(term(), keyword() | map()) :: [map()]
  def rewards_optimization(payload, opts \\ []) do
    policy = policy(opts)

    payload
    |> stablecoin_pools()
    |> Enum.map(fn pool ->
      reward_score = pool.reward_apy + pool.crv_apy

      pool
      |> Map.put(:reward_score, reward_score)
      |> Map.put(:score, reward_score * policy.reward_weight + liquidity_score(pool))
    end)
    |> Enum.sort_by(& &1.score, :desc)
  end

  @doc "Summarizes existing Curve positions by pool."
  @spec position_monitor([map()], term()) :: map()
  def position_monitor(positions, pool_payload) when is_list(positions) do
    pools_by_address =
      pool_payload
      |> pools()
      |> Map.new(&{String.downcase(&1.address || ""), &1})

    monitored =
      Enum.map(positions, fn position ->
        pool = Map.get(pools_by_address, String.downcase(value(position, :pool_address, "")), %{})
        lp_amount = numeric(value(position, :lp_amount, 0))
        lp_price = numeric(value(pool, :virtual_price, value(position, :lp_price, 1)))
        value_usd = numeric(value(position, :value_usd, lp_amount * lp_price))

        %{
          pool_address: value(position, :pool_address),
          pool: value(pool, :name, value(position, :pool)),
          lp_amount: lp_amount,
          value_usd: value_usd,
          gauge_address: value(pool, :gauge_address),
          estimated_apy: numeric(value(pool, :total_apy, value(position, :estimated_apy, 0))),
          reward_tokens: value(pool, :reward_tokens, [])
        }
      end)

    %{
      positions: monitored,
      total_value_usd: monitored |> Enum.map(& &1.value_usd) |> Enum.sum(),
      weighted_apy: weighted_average(monitored, :estimated_apy, :value_usd)
    }
  end

  @doc "Creates a stablecoin rebalance plan from current to target allocations."
  @spec rebalance_plan(map(), keyword() | map()) :: map()
  def rebalance_plan(current_allocations, opts \\ []) when is_map(current_allocations) do
    policy = policy(opts)
    target_allocations = value(opts, :target_allocations, policy.target_allocations) |> opts_map()
    threshold = numeric(value(opts, :threshold_pct, 0.02))

    actions =
      target_allocations
      |> Enum.map(fn {asset, target_pct} ->
        current_pct = numeric(value(current_allocations, asset, 0))
        drift = current_pct - numeric(target_pct)

        %{
          asset: asset,
          current_pct: current_pct,
          target_pct: numeric(target_pct),
          drift_pct: drift,
          action: rebalance_action(drift, threshold)
        }
      end)
      |> Enum.reject(&(&1.action == :hold))

    %{status: if(actions == [], do: :balanced, else: :rebalance_required), actions: actions}
  end

  @doc "Checks expected swap/deposit slippage against policy."
  @spec slippage_check(map(), keyword() | map()) :: {:ok, map()} | {:error, map()}
  def slippage_check(route, opts \\ []) do
    policy = policy(opts)
    amount_in = numeric(value(route, :amount_in, 0))
    expected_out = numeric(value(route, :expected_out, 0))
    min_out = numeric(value(route, :min_out, expected_out))

    slippage = if expected_out > 0, do: (expected_out - min_out) / expected_out, else: 1.0

    decision = %{
      amount_in: amount_in,
      expected_out: expected_out,
      min_out: min_out,
      slippage_pct: slippage,
      max_slippage_pct: policy.max_slippage_pct,
      route: value(route, :route, [])
    }

    if amount_in > 0 and slippage <= policy.max_slippage_pct do
      {:ok, Map.put(decision, :decision, :approved)}
    else
      {:error, Map.put(decision, :decision, :blocked)}
    end
  end

  @doc "Ranks candidate routes by slippage policy and expected output."
  @spec slippage_optimization([map()], keyword() | map()) :: [map()]
  def slippage_optimization(routes, opts \\ []) when is_list(routes) do
    routes
    |> Enum.map(fn route ->
      case slippage_check(route, opts) do
        {:ok, decision} -> Map.put(decision, :status, :approved)
        {:error, decision} -> Map.put(decision, :status, :blocked)
      end
    end)
    |> Enum.sort_by(&{&1.status == :blocked, &1.slippage_pct, -&1.expected_out})
  end

  @doc "Builds a compact Curve stablecoin management dashboard."
  @spec dashboard(map(), keyword() | map()) :: map()
  def dashboard(input, opts \\ []) do
    pool_payload = value(input, :pools, %{})
    positions = value(input, :positions, [])

    %{
      top_pools: pool_analysis(pool_payload, opts) |> Enum.take(value(opts, :limit, 5)),
      rewards: rewards_optimization(pool_payload, opts) |> Enum.take(value(opts, :limit, 5)),
      positions: position_monitor(positions, pool_payload),
      rebalance: rebalance_plan(value(input, :allocations, %{}), opts)
    }
  end

  defp score_pool(pool, policy) do
    slippage_penalty = max(numeric(pool.fee_pct), 0.0) * policy.slippage_weight
    reward_score = (pool.base_apy + pool.crv_apy + pool.reward_apy) * policy.reward_weight
    volume_score = log_score(pool.volume_usd) * policy.volume_weight
    tvl_score = log_score(pool.tvl_usd) * policy.tvl_weight
    concentration_penalty = max(pool.max_coin_pct - policy.max_pool_concentration_pct, 0.0)

    Map.put(
      pool,
      :score,
      reward_score + volume_score + tvl_score - slippage_penalty - concentration_penalty
    )
  end

  defp stablecoin_pool?(%{coins: coins}) do
    stable_count = Enum.count(coins, &CurveFinance.stablecoin_symbol?(&1.symbol))
    length(coins) >= 2 and stable_count >= max(2, length(coins) - 1)
  end

  defp normalize_pool(%{} = pool) do
    coins = normalize_coins(value(pool, :coins, value(pool, :underlyingCoins, [])))
    tvl = numeric(value(pool, :usdTotal, value(pool, :tvlUsd, value(pool, :tvl, 0))))

    volume =
      numeric(value(pool, :volumeUSD, value(pool, :volumeUsd, value(pool, :dailyVolume, 0))))

    base_apy = apy_value(pool, [:apy, :baseApy, :base_apy])
    crv_apy = apy_value(pool, [:gaugeCrvApy, :crvApy, :crv_apy])
    reward_apy = apy_value(pool, [:gaugeRewardsApy, :rewardApy, :rewardsApy])
    total_apy = numeric(value(pool, :total_apy, base_apy + crv_apy + reward_apy))

    %{
      id: value(pool, :id, value(pool, :address)),
      name: value(pool, :name, value(pool, :symbol, "Curve Pool")),
      address: value(pool, :address),
      chain: value(pool, :blockchainId, value(pool, :chain)),
      registry: value(pool, :registryId, value(pool, :registry)),
      lp_token_address: value(pool, :lpTokenAddress, value(pool, :lp_token_address)),
      gauge_address: value(pool, :gaugeAddress, value(pool, :gauge_address)),
      coins: coins,
      tvl_usd: tvl,
      volume_usd: volume,
      fee_pct: fee_pct(pool),
      base_apy: base_apy,
      crv_apy: crv_apy,
      reward_apy: reward_apy,
      total_apy: total_apy,
      virtual_price: numeric(value(pool, :virtualPrice, value(pool, :virtual_price, 1))),
      reward_tokens: reward_tokens(pool),
      max_coin_pct: max_coin_pct(coins)
    }
  end

  defp normalize_coins(coins) when is_list(coins) do
    Enum.map(coins, fn
      %{} = coin ->
        %{
          symbol: value(coin, :symbol, value(coin, :name)),
          address: value(coin, :address),
          balance: numeric(value(coin, :poolBalance, value(coin, :balance, 0))),
          usd_price: numeric(value(coin, :usdPrice, value(coin, :price, 1)))
        }

      symbol when is_binary(symbol) ->
        %{symbol: symbol, address: nil, balance: 0.0, usd_price: 1.0}
    end)
  end

  defp normalize_coins(_coins), do: []

  defp pool_items(%{} = payload) do
    data = value(payload, :data, payload)

    cond do
      is_list(value(data, :poolData)) -> value(data, :poolData)
      is_list(value(data, :pools)) -> value(data, :pools)
      is_list(data) -> data
      true -> []
    end
  end

  defp pool_items(items) when is_list(items), do: items
  defp pool_items(_payload), do: []

  defp reward_tokens(pool) do
    pool
    |> value(:reward_tokens, value(pool, :gaugeRewards, value(pool, :rewardTokens, [])))
    |> List.wrap()
    |> Enum.map(fn
      %{} = reward ->
        value(reward, :tokenAddress, value(reward, :address, value(reward, :symbol)))

      reward ->
        reward
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp apy_value(pool, keys) do
    keys
    |> Enum.map(&numeric(value(pool, &1, nil)))
    |> Enum.find(0.0, &(&1 > 0))
  end

  defp fee_pct(pool) do
    fee = numeric(value(pool, :fee, value(pool, :feePct, 0)))
    if fee > 1, do: fee / 1.0e10, else: fee
  end

  defp max_coin_pct(coins) do
    balances = Enum.map(coins, &(&1.balance * max(&1.usd_price, 1.0)))
    total = Enum.sum(balances)
    if total > 0, do: Enum.max(balances) / total, else: 0.0
  end

  defp liquidity_score(pool), do: log_score(pool.tvl_usd) + log_score(pool.volume_usd)

  defp log_score(value) when value > 0, do: :math.log10(value + 1) / 10
  defp log_score(_value), do: 0.0

  defp weighted_average(items, value_key, weight_key) do
    total_weight = items |> Enum.map(&numeric(value(&1, weight_key, 0))) |> Enum.sum()

    if total_weight == 0 do
      0.0
    else
      weighted_sum =
        items
        |> Enum.map(&(numeric(value(&1, value_key, 0)) * numeric(value(&1, weight_key, 0))))
        |> Enum.sum()

      weighted_sum / total_weight
    end
  end

  defp rebalance_action(drift, threshold) when drift > threshold, do: :reduce
  defp rebalance_action(drift, threshold) when drift < -threshold, do: :increase
  defp rebalance_action(_drift, _threshold), do: :hold

  defp policy(opts) do
    Map.merge(@default_policy, opts |> value(:policy, %{}) |> opts_map())
  end

  defp value(map, key, default \\ nil)
  defp value(map, key, default) when is_map(map), do: map_get(map, key, default)
  defp value(list, key, default) when is_list(list), do: Keyword.get(list, key, default)
  defp value(_other, _key, default), do: default

  defp map_get(map, key, default) do
    string_key = to_string(key)

    cond do
      Map.has_key?(map, key) -> Map.fetch!(map, key)
      Map.has_key?(map, string_key) -> Map.fetch!(map, string_key)
      true -> default
    end
  end

  defp opts_map(opts) when is_map(opts), do: opts
  defp opts_map(opts) when is_list(opts), do: Map.new(opts)

  defp numeric(nil), do: 0.0
  defp numeric(value) when is_integer(value), do: value * 1.0
  defp numeric(value) when is_float(value), do: value

  defp numeric(value) when is_binary(value) do
    case Float.parse(value) do
      {number, _rest} -> number
      :error -> 0.0
    end
  end

  defp numeric(_value), do: 0.0
end
