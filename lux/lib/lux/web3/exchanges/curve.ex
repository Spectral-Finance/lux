defmodule Lux.Web3.Exchanges.Curve do
  @moduledoc """
  Curve Finance integration and stablecoin management engine for Lux agents.

  Provides comprehensive capabilities for interacting with Curve Finance protocols:
  - **Pool Discovery & Registry**: Inspects StableSwap (`A` amplification invariant)
    and CryptoSwap pools across Ethereum, Arbitrum, Optimism, and Polygon.
  - **`get_dy` Swap Routing**: Calculates deterministic StableSwap and CryptoSwap output
    quotes, effective exchange rates, price impact, and optimal multi-pool routes.
  - **Liquidity Provision & Removal**: Simulates and executes balanced/single-sided
    `add_liquidity`, `remove_liquidity`, and `remove_liquidity_one_coin` with slippage bounds.
  - **Gauge Staking & CRV Optimization**: Tracks liquidity gauge deposits, computes CRV
    vote-escrow (`veCRV`) boost multipliers (up to `2.5x`), and claims CRV + external rewards.
  - **Stablecoin Peg & Depeg Health Monitor**: Evaluates coin balance ratios, virtual price
    growth, depeg severity alerts, and automated yield/peg rebalancing recommendations.
  """

  @table :lux_curve_state
  @basis_points 10_000

  @default_pools %{
    "3pool" => %{
      id: "3pool",
      name: "Curve.fi DAI/USDC/USDT (3pool)",
      address: "0xbebc44782c7db0a1a60cb6fe97d0b483032ff1c7",
      lp_token: "0x6c3f90f043a72fa612cbac8115ee7e52bde6e490",
      gauge: "0xbfcf63294ad7105dea65aa58f8ae5be2d9d0952a",
      chain: :ethereum,
      pool_type: :stableswap,
      coins: ["DAI", "USDC", "USDT"],
      decimals: [18, 6, 6],
      balances: [45_000_000.0, 48_000_000.0, 47_000_000.0],
      amplification: 2000,
      fee_bps: 4,
      virtual_price: 1.0315,
      base_apy: 3.45,
      crv_apy_range: {1.80, 4.50},
      tvl_usd: 140_000_000.0
    },
    "frax_usdc" => %{
      id: "frax_usdc",
      name: "Curve.fi FRAX/USDC",
      address: "0xdcef968d416a41cdac0ed8702fac8128a64241a2",
      lp_token: "0x3175df0976dfa876431c2e9ee6bc45b65d3473cc",
      gauge: "0xcfc25170633581bf896cb6c57a3c7e3b17003b9a",
      chain: :ethereum,
      pool_type: :stableswap,
      coins: ["FRAX", "USDC"],
      decimals: [18, 6],
      balances: [32_000_000.0, 34_000_000.0],
      amplification: 1500,
      fee_bps: 4,
      virtual_price: 1.0182,
      base_apy: 4.20,
      crv_apy_range: {2.40, 6.00},
      tvl_usd: 66_000_000.0
    },
    "crvusd_usdc" => %{
      id: "crvusd_usdc",
      name: "Curve.fi crvUSD/USDC",
      address: "0x4dece678ceceb27446b35c672dc7d61f30bad69e",
      lp_token: "0x4dece678ceceb27446b35c672dc7d61f30bad69e",
      gauge: "0x95f00391cb5eebcd190eb58728b4ce23dbfa6ac1",
      chain: :ethereum,
      pool_type: :stableswap,
      coins: ["crvUSD", "USDC"],
      decimals: [18, 6],
      balances: [28_500_000.0, 29_500_000.0],
      amplification: 500,
      fee_bps: 4,
      virtual_price: 1.0094,
      base_apy: 5.80,
      crv_apy_range: {3.20, 8.00},
      tvl_usd: 58_000_000.0
    },
    "tricrypto2" => %{
      id: "tricrypto2",
      name: "Curve.fi USDT/WBTC/WETH (TriCrypto2)",
      address: "0xd51a44d3fae010294c616388b506acda1bfaae46",
      lp_token: "0xc4ad29ba4b3c580e6d59105fff484999997675ff",
      gauge: "0xdefd8fdd20e0f34115c7018ccfb655796f6b2168",
      chain: :ethereum,
      pool_type: :cryptoswap,
      coins: ["USDT", "WBTC", "WETH"],
      decimals: [6, 8, 18],
      balances: [65_000_000.0, 950.0, 22_000.0],
      spot_prices_usd: %{"USDT" => 1.0, "WBTC" => 68_000.0, "WETH" => 3_000.0},
      amplification: 400,
      fee_bps: 15,
      virtual_price: 1.0840,
      base_apy: 7.50,
      crv_apy_range: {3.50, 8.75},
      tvl_usd: 195_600_000.0
    }
  }

  @type pool_id :: String.t()
  @type pool :: map()

  @doc """
  Lists available Curve Finance pools with optional filtering by `:chain`, `:pool_type`,
  or `:coin`.
  """
  @spec list_pools(keyword()) :: {:ok, [pool()]}
  def list_pools(opts \\ []) do
    ensure_table!()
    chain_filter = Keyword.get(opts, :chain)
    type_filter = Keyword.get(opts, :pool_type)
    coin_filter = Keyword.get(opts, :coin)

    pools =
      all_pools_map()
      |> Map.values()
      |> Enum.filter(fn pool ->
        chain_match?(pool, chain_filter) and
          type_match?(pool, type_filter) and
          coin_match?(pool, coin_filter)
      end)
      |> Enum.sort_by(& &1.id)

    {:ok, pools}
  end

  @doc """
  Retrieves metadata and live reserve state for a specific Curve pool.
  """
  @spec get_pool(pool_id()) :: {:ok, pool()} | {:error, :pool_not_found}
  def get_pool(pool_id) when is_binary(pool_id) do
    ensure_table!()

    case Map.get(all_pools_map(), pool_id) do
      nil -> {:error, :pool_not_found}
      pool -> {:ok, pool}
    end
  end

  @doc """
  Registers or updates a Curve pool in the local registry for analysis or testing.
  """
  @spec register_pool(pool()) :: {:ok, pool()} | {:error, atom()}
  def register_pool(%{id: id, coins: coins, balances: balances} = pool)
      when is_binary(id) and is_list(coins) and is_list(balances) and
             length(coins) == length(balances) do
    ensure_table!()
    custom_pools = get_state(:custom_pools, %{})
    updated = Map.put(custom_pools, id, pool)
    put_state(:custom_pools, updated)
    {:ok, pool}
  end

  def register_pool(_invalid), do: {:error, :invalid_pool_spec}

  @doc """
  Computes the expected swap output (`dy`) for exchanging `dx` of `from_coin` into `to_coin`
  within a given Curve pool, modeling amplification (`A`), pool balance skew, and fees.
  """
  @spec get_dy(pool_id(), String.t(), String.t(), number()) ::
          {:ok, map()} | {:error, atom()}
  def get_dy(pool_id, from_coin, to_coin, dx)
      when is_binary(pool_id) and is_binary(from_coin) and is_binary(to_coin) and is_number(dx) do
    cond do
      dx <= 0 ->
        {:error, :invalid_amount}

      from_coin == to_coin ->
        {:error, :identical_coins}

      true ->
        with {:ok, pool} <- get_pool(pool_id),
             {:ok, i} <- coin_index(pool, from_coin),
             {:ok, j} <- coin_index(pool, to_coin) do
          compute_pool_dy(pool, i, j, from_coin, to_coin, dx * 1.0)
        end
    end
  end

  @doc """
  Finds the optimal swap route across all registered Curve pools for exchanging `from_coin`
  to `to_coin`, ranking candidate pools by highest net output (`dy`) and lowest slippage.
  """
  @spec find_best_route(String.t(), String.t(), number(), keyword()) ::
          {:ok, map()} | {:error, atom()}
  def find_best_route(from_coin, to_coin, dx, opts \\ [])
      when is_binary(from_coin) and is_binary(to_coin) and is_number(dx) do
    max_slippage_bps = Keyword.get(opts, :max_slippage_bps, 50)
    {:ok, pools} = list_pools(opts)

    candidates =
      pools
      |> Enum.filter(fn pool ->
        from_coin in pool.coins and to_coin in pool.coins
      end)
      |> Enum.reduce([], fn pool, acc ->
        case get_dy(pool.id, from_coin, to_coin, dx) do
          {:ok, quote_data} -> [quote_data | acc]
          _ -> acc
        end
      end)
      |> Enum.sort_by(& &1.dy, :desc)

    case candidates do
      [best | _] ->
        min_dy = Float.round(best.dy * (1.0 - max_slippage_bps / @basis_points), 6)

        {:ok,
         %{
           best_pool_id: best.pool_id,
           from_coin: from_coin,
           to_coin: to_coin,
           dx: dx * 1.0,
           expected_dy: best.dy,
           min_dy: min_dy,
           price_impact_bps: best.price_impact_bps,
           fee_amount: best.fee_amount,
           alternatives: Enum.map(candidates, &Map.take(&1, [:pool_id, :dy, :price_impact_bps]))
         }}

      [] ->
        {:error, :no_route_found}
    end
  end

  @doc """
  Executes a swap on a Curve pool with slippage protection (`min_dy`), updating pool
  balances and recording the swap receipt.
  """
  @spec execute_swap(pool_id(), String.t(), String.t(), number(), number(), keyword()) ::
          {:ok, map()} | {:error, atom()}
  def execute_swap(pool_id, from_coin, to_coin, dx, min_dy, opts \\ []) do
    wallet = Keyword.get(opts, :wallet, "0x0000000000000000000000000000000000000001")

    with {:ok, quote_data} <- get_dy(pool_id, from_coin, to_coin, dx),
         :ok <- verify_slippage(quote_data.dy, min_dy),
         {:ok, pool} <- get_pool(pool_id),
         {:ok, i} <- coin_index(pool, from_coin),
         {:ok, j} <- coin_index(pool, to_coin) do
      new_balances =
        pool.balances
        |> List.update_at(i, &(&1 + dx))
        |> List.update_at(j, &max(0.0, &1 - quote_data.dy))

      updated_pool = %{pool | balances: new_balances}
      register_pool(updated_pool)

      {:ok,
       %{
         tx_hash: generate_tx_hash({:swap, pool_id, from_coin, to_coin, dx, wallet}),
         pool_id: pool_id,
         wallet: wallet,
         from_coin: from_coin,
         to_coin: to_coin,
         dx: dx * 1.0,
         dy: quote_data.dy,
         min_dy: min_dy * 1.0,
         fee_amount: quote_data.fee_amount,
         price_impact_bps: quote_data.price_impact_bps,
         executed_at: DateTime.utc_now() |> DateTime.to_iso8601()
       }}
    end
  end

  @doc """
  Adds liquidity to a Curve pool and mints LP tokens for `wallet`, enforcing `min_mint_amount`
  slippage protection and accounting for imbalance fees when depositing unevenly.
  """
  @spec add_liquidity(pool_id(), [number()], number(), keyword()) ::
          {:ok, map()} | {:error, atom()}
  def add_liquidity(pool_id, amounts, min_mint_amount \\ 0.0, opts \\ [])
      when is_binary(pool_id) and is_list(amounts) do
    wallet = Keyword.get(opts, :wallet, "0x0000000000000000000000000000000000000001")

    with {:ok, pool} <- get_pool(pool_id),
         :ok <- validate_deposit_amounts(pool, amounts) do
      usd_value = compute_deposit_usd(pool, amounts)
      imbalance_penalty_bps = compute_imbalance_penalty_bps(pool, amounts)
      effective_usd = usd_value * (1.0 - imbalance_penalty_bps / @basis_points)
      lp_minted = Float.round(effective_usd / pool.virtual_price, 6)

      if lp_minted < min_mint_amount do
        {:error, :slippage_exceeded}
      else
        new_balances =
          Enum.zip_with(pool.balances, amounts, fn bal, amt -> bal + amt end)

        register_pool(%{pool | balances: new_balances, tvl_usd: pool.tvl_usd + usd_value})
        update_lp_position(wallet, pool_id, lp_minted)

        {:ok,
         %{
           tx_hash: generate_tx_hash({:add_liquidity, pool_id, amounts, wallet}),
           pool_id: pool_id,
           wallet: wallet,
           amounts_deposited: amounts,
           lp_tokens_minted: lp_minted,
           virtual_price: pool.virtual_price,
           imbalance_penalty_bps: imbalance_penalty_bps,
           lp_balance: get_lp_balance(wallet, pool_id)
         }}
      end
    end
  end

  @doc """
  Removes liquidity from a Curve pool either proportionally (`:balanced`) or single-sided
  (`{:one_coin, coin_symbol}`), burning `lp_amount` LP tokens.
  """
  @spec remove_liquidity(pool_id(), number(), :balanced | {:one_coin, String.t()}, keyword()) ::
          {:ok, map()} | {:error, atom()}
  def remove_liquidity(pool_id, lp_amount, mode \\ :balanced, opts \\ [])
      when is_binary(pool_id) and is_number(lp_amount) do
    wallet = Keyword.get(opts, :wallet, "0x0000000000000000000000000000000000000001")
    min_amount = Keyword.get(opts, :min_amount, 0.0)

    with {:ok, pool} <- get_pool(pool_id),
         :ok <- validate_lp_burn(wallet, pool_id, lp_amount),
         {:ok, withdrawn, total_usd} <- calculate_withdrawal(pool, lp_amount, mode) do
      if total_usd < min_amount do
        {:error, :slippage_exceeded}
      else
        update_lp_position(wallet, pool_id, -lp_amount)

        {:ok,
         %{
           tx_hash: generate_tx_hash({:remove_liquidity, pool_id, lp_amount, wallet}),
           pool_id: pool_id,
           wallet: wallet,
           lp_tokens_burned: lp_amount * 1.0,
           mode: mode,
           withdrawn: withdrawn,
           usd_value: total_usd,
           remaining_lp_balance: get_lp_balance(wallet, pool_id)
         }}
      end
    end
  end

  @doc """
  Stakes Curve LP tokens into the pool's liquidity gauge and calculates the user's
  `veCRV` boost factor (`1.0x` to `2.5x`) and effective APY.
  """
  @spec stake_in_gauge(pool_id(), number(), keyword()) :: {:ok, map()} | {:error, atom()}
  def stake_in_gauge(pool_id, lp_amount, opts \\ [])
      when is_binary(pool_id) and is_number(lp_amount) do
    wallet = Keyword.get(opts, :wallet, "0x0000000000000000000000000000000000000001")
    vecrv_balance = Keyword.get(opts, :vecrv_balance, 0.0)
    total_vecrv = Keyword.get(opts, :total_vecrv, 500_000_000.0)

    with {:ok, pool} <- get_pool(pool_id),
         :ok <- validate_lp_burn(wallet, pool_id, lp_amount) do
      update_lp_position(wallet, pool_id, -lp_amount)
      staked = update_gauge_stake(wallet, pool_id, lp_amount)

      boost = calculate_vecrv_boost(staked, pool.tvl_usd, vecrv_balance, total_vecrv)
      {min_crv_apy, max_crv_apy} = pool.crv_apy_range
      effective_crv_apy = Float.round(min_crv_apy * boost, 4)
      total_apy = Float.round(pool.base_apy + min(effective_crv_apy, max_crv_apy), 4)

      {:ok,
       %{
         tx_hash: generate_tx_hash({:stake_gauge, pool_id, lp_amount, wallet}),
         pool_id: pool_id,
         gauge: pool.gauge,
         wallet: wallet,
         staked_lp_amount: staked,
         boost_multiplier: boost,
         base_apy: pool.base_apy,
         crv_apy: min(effective_crv_apy, max_crv_apy),
         total_effective_apy: total_apy
       }}
    end
  end

  @doc """
  Unstakes LP tokens from a Curve liquidity gauge and returns them to the wallet's LP balance.
  """
  @spec unstake_from_gauge(pool_id(), number(), keyword()) :: {:ok, map()} | {:error, atom()}
  def unstake_from_gauge(pool_id, lp_amount, opts \\ [])
      when is_binary(pool_id) and is_number(lp_amount) do
    wallet = Keyword.get(opts, :wallet, "0x0000000000000000000000000000000000000001")
    current_staked = get_gauge_stake(wallet, pool_id)

    cond do
      lp_amount <= 0 ->
        {:error, :invalid_amount}

      current_staked < lp_amount ->
        {:error, :insufficient_gauge_stake}

      true ->
        remaining = update_gauge_stake(wallet, pool_id, -lp_amount)
        update_lp_position(wallet, pool_id, lp_amount)

        {:ok,
         %{
           tx_hash: generate_tx_hash({:unstake_gauge, pool_id, lp_amount, wallet}),
           pool_id: pool_id,
           wallet: wallet,
           unstaked_lp: lp_amount * 1.0,
           remaining_gauge_stake: remaining,
           wallet_lp_balance: get_lp_balance(wallet, pool_id)
         }}
    end
  end

  @doc """
  Claims accrued `CRV` emissions and any external gauge rewards for a staked position.
  Supports optional auto-compounding or locking into `veCRV`.
  """
  @spec claim_rewards(pool_id(), keyword()) :: {:ok, map()} | {:error, atom()}
  def claim_rewards(pool_id, opts \\ []) when is_binary(pool_id) do
    wallet = Keyword.get(opts, :wallet, "0x0000000000000000000000000000000000000001")
    days_elapsed = Keyword.get(opts, :days_elapsed, 7)
    crv_price_usd = Keyword.get(opts, :crv_price_usd, 0.45)
    vecrv_balance = Keyword.get(opts, :vecrv_balance, 25_000.0)
    compound = Keyword.get(opts, :compound, false)

    with {:ok, pool} <- get_pool(pool_id) do
      staked_lp = get_gauge_stake(wallet, pool_id)

      if staked_lp <= 0 do
        {:error, :no_active_gauge_stake}
      else
        boost = calculate_vecrv_boost(staked_lp, pool.tvl_usd, vecrv_balance, 500_000_000.0)
        {min_crv_apy, max_crv_apy} = pool.crv_apy_range
        crv_apy = min(min_crv_apy * boost, max_crv_apy)
        staked_usd = staked_lp * pool.virtual_price
        reward_usd = Float.round(staked_usd * (crv_apy / 100.0) * (days_elapsed / 365.0), 4)
        crv_claimed = Float.round(reward_usd / crv_price_usd, 4)

        compounded_lp =
          if compound do
            added_lp = Float.round(reward_usd / pool.virtual_price, 6)
            update_gauge_stake(wallet, pool_id, added_lp)
            added_lp
          else
            0.0
          end

        {:ok,
         %{
           tx_hash: generate_tx_hash({:claim_crv, pool_id, wallet, days_elapsed}),
           pool_id: pool_id,
           wallet: wallet,
           crv_claimed: crv_claimed,
           reward_usd: reward_usd,
           boost_multiplier: boost,
           compounded: compound,
           compounded_lp_added: compounded_lp
         }}
      end
    end
  end

  @doc """
  Monitors stablecoin peg health and reserve composition of a Curve StableSwap pool.
  Detects coin concentration skew, estimates implied depeg in basis points, and emits
  risk status (`:healthy`, `:warning`, or `:critical_depeg`).
  """
  @spec analyze_peg_health(pool_id(), keyword()) :: {:ok, map()} | {:error, atom()}
  def analyze_peg_health(pool_id, opts \\ []) when is_binary(pool_id) do
    warning_skew_pct = Keyword.get(opts, :warning_skew_pct, 60.0)
    critical_skew_pct = Keyword.get(opts, :critical_skew_pct, 75.0)

    with {:ok, pool} <- get_pool(pool_id) do
      total_balance = Enum.sum(pool.balances)
      n = length(pool.coins)
      ideal_share_pct = 100.0 / n

      composition =
        Enum.zip(pool.coins, pool.balances)
        |> Enum.map(fn {coin, bal} ->
          share_pct =
            if total_balance > 0, do: Float.round(bal / total_balance * 100.0, 2), else: 0.0

          deviation_pct = Float.round(share_pct - ideal_share_pct, 2)

          implied_peg =
            Float.round(
              1.0 - deviation_pct / 100.0 * (1000.0 / max(pool.amplification, 100)),
              5
            )

          %{
            coin: coin,
            balance: bal,
            share_pct: share_pct,
            deviation_pct: deviation_pct,
            implied_peg_usd: implied_peg
          }
        end)

      max_coin_entry = Enum.max_by(composition, & &1.share_pct)

      status =
        cond do
          max_coin_entry.share_pct >= critical_skew_pct -> :critical_depeg
          max_coin_entry.share_pct >= warning_skew_pct -> :warning
          true -> :healthy
        end

      recommendation =
        case status do
          :critical_depeg ->
            "Immediate single-sided exit recommended; " <>
              "#{max_coin_entry.coin} severely overweight (#{max_coin_entry.share_pct}%)"

          :warning ->
            "Monitor closely or rebalance partially; #{max_coin_entry.coin} reserve share elevated (#{max_coin_entry.share_pct}%)"

          :healthy ->
            "Pool reserves well balanced around #{Float.round(ideal_share_pct, 1)}% target share"
        end

      {:ok,
       %{
         pool_id: pool_id,
         status: status,
         dominant_coin: max_coin_entry.coin,
         max_share_pct: max_coin_entry.share_pct,
         virtual_price: pool.virtual_price,
         amplification: pool.amplification,
         composition: composition,
         recommendation: recommendation
       }}
    end
  end

  @doc """
  Generates an automated portfolio rebalancing plan across Curve stablecoin pools to
  maximize risk-adjusted yield (`total_apy`) while avoiding pools experiencing peg warnings.
  """
  @spec optimize_yield_rebalance(String.t(), keyword()) :: {:ok, map()}
  def optimize_yield_rebalance(wallet, opts \\ []) when is_binary(wallet) do
    vecrv_balance = Keyword.get(opts, :vecrv_balance, 25_000.0)
    min_apy_improvement = Keyword.get(opts, :min_apy_improvement, 0.50)

    {:ok, pools} = list_pools(pool_type: :stableswap)

    scored_pools =
      pools
      |> Enum.map(fn pool ->
        {:ok, health} = analyze_peg_health(pool.id)
        boost = calculate_vecrv_boost(10_000.0, pool.tvl_usd, vecrv_balance, 500_000_000.0)
        {min_crv, max_crv} = pool.crv_apy_range
        effective_apy = Float.round(pool.base_apy + min(min_crv * boost, max_crv), 4)

        risk_adjusted_score =
          case health.status do
            :healthy -> effective_apy
            :warning -> effective_apy * 0.5
            :critical_depeg -> 0.0
          end

        %{
          pool_id: pool.id,
          name: pool.name,
          peg_status: health.status,
          effective_apy: effective_apy,
          risk_adjusted_score: Float.round(risk_adjusted_score, 4)
        }
      end)
      |> Enum.sort_by(& &1.risk_adjusted_score, :desc)

    best_target = List.first(scored_pools)
    positions = get_wallet_positions(wallet)

    actions =
      Enum.flat_map(positions, fn {pool_id, pos} ->
        total_lp = pos.lp_balance + pos.gauge_staked
        current_pool = Enum.find(scored_pools, &(&1.pool_id == pool_id))

        cond do
          total_lp <= 0 or is_nil(current_pool) ->
            []

          current_pool.peg_status == :critical_depeg ->
            [
              %{
                action: :emergency_exit,
                from_pool: pool_id,
                to_pool: best_target.pool_id,
                lp_amount: total_lp,
                reason: "Critical depeg detected in #{pool_id}"
              }
            ]

          best_target.pool_id != pool_id and
              best_target.risk_adjusted_score - current_pool.risk_adjusted_score >=
                min_apy_improvement ->
            [
              %{
                action: :rebalance_for_yield,
                from_pool: pool_id,
                to_pool: best_target.pool_id,
                lp_amount: total_lp,
                apy_delta:
                  Float.round(best_target.effective_apy - current_pool.effective_apy, 4),
                reason:
                  "Higher risk-adjusted APY in #{best_target.pool_id} " <>
                    "(#{best_target.effective_apy}% vs #{current_pool.effective_apy}%)"
              }
            ]

          true ->
            []
        end
      end)

    {:ok,
     %{
       wallet: wallet,
       optimal_pool: best_target,
       ranked_pools: scored_pools,
       recommended_actions: actions
     }}
  end

  @doc """
  Returns all LP token and gauge-staked positions for a given wallet address.
  """
  @spec get_positions(String.t()) :: {:ok, map()}
  def get_positions(wallet) when is_binary(wallet) do
    ensure_table!()
    {:ok, get_wallet_positions(wallet)}
  end

  @doc """
  Resets all mutable in-memory Curve pools and positions back to default state.
  """
  @spec reset_state!() :: :ok
  def reset_state! do
    ensure_table!()
    :ets.delete_all_objects(@table)
    :ok
  end

  # Private helpers

  defp compute_pool_dy(pool, i, j, from_coin, to_coin, dx) do
    bal_i = Enum.at(pool.balances, i)
    bal_j = Enum.at(pool.balances, j)
    fee_rate = pool.fee_bps / @basis_points

    raw_dy =
      case pool.pool_type do
        :stableswap ->
          amp = max(pool.amplification, 1)
          skew_ratio = bal_i / max(bal_j, 1.0)
          trade_depth = dx / max(bal_j, 1.0)
          slippage_factor = 1.0 / (1.0 + (skew_ratio - 1.0) / amp + trade_depth / (amp * 0.5))
          dx * min(max(slippage_factor, 0.85), 1.02)

        :cryptoswap ->
          prices = Map.get(pool, :spot_prices_usd, %{})
          price_i = Map.get(prices, from_coin, 1.0)
          price_j = Map.get(prices, to_coin, 1.0)
          usd_in = dx * price_i
          trade_depth = usd_in / max(bal_j * price_j, 1.0)
          amm_impact = 1.0 / (1.0 + trade_depth * 0.5)
          usd_in / price_j * amm_impact
      end

    fee_amount = Float.round(raw_dy * fee_rate, 6)
    net_dy = Float.round(raw_dy - fee_amount, 6)

    ideal_dy =
      case pool.pool_type do
        :stableswap ->
          dx

        :cryptoswap ->
          prices = Map.get(pool, :spot_prices_usd, %{})
          dx * Map.get(prices, from_coin, 1.0) / Map.get(prices, to_coin, 1.0)
      end

    price_impact_bps =
      max(0.0, Float.round((ideal_dy - raw_dy) / max(ideal_dy, 1.0e-9) * @basis_points, 2))

    {:ok,
     %{
       pool_id: pool.id,
       pool_type: pool.pool_type,
       from_coin: from_coin,
       to_coin: to_coin,
       dx: dx,
       dy: net_dy,
       fee_amount: fee_amount,
       effective_rate: Float.round(net_dy / dx, 6),
       price_impact_bps: price_impact_bps
     }}
  end

  defp coin_index(pool, coin) do
    case Enum.find_index(pool.coins, &(&1 == coin)) do
      nil -> {:error, :coin_not_in_pool}
      idx -> {:ok, idx}
    end
  end

  defp verify_slippage(dy, min_dy) when dy >= min_dy, do: :ok
  defp verify_slippage(_dy, _min_dy), do: {:error, :slippage_exceeded}

  defp validate_deposit_amounts(pool, amounts) do
    cond do
      length(amounts) != length(pool.coins) ->
        {:error, :invalid_coins_length}

      Enum.any?(amounts, &(&1 < 0)) or Enum.sum(amounts) <= 0 ->
        {:error, :invalid_amount}

      true ->
        :ok
    end
  end

  defp compute_deposit_usd(%{pool_type: :cryptoswap, coins: coins} = pool, amounts) do
    prices = Map.get(pool, :spot_prices_usd, %{})

    Enum.zip(coins, amounts)
    |> Enum.reduce(0.0, fn {coin, amt}, acc ->
      acc + amt * Map.get(prices, coin, 1.0)
    end)
  end

  defp compute_deposit_usd(_pool, amounts), do: Enum.sum(amounts) * 1.0

  defp compute_imbalance_penalty_bps(pool, amounts) do
    total = Enum.sum(amounts) * 1.0
    n = length(amounts)
    ideal_share = 1.0 / n

    deviation =
      Enum.reduce(amounts, 0.0, fn amt, acc ->
        acc + abs(amt / total - ideal_share)
      end)

    Float.round(deviation * (pool.fee_bps * 0.5), 2)
  end

  defp validate_lp_burn(_wallet, _pool_id, lp_amount) when lp_amount <= 0,
    do: {:error, :invalid_amount}

  defp validate_lp_burn(wallet, pool_id, lp_amount) do
    if get_lp_balance(wallet, pool_id) >= lp_amount do
      :ok
    else
      {:error, :insufficient_lp_balance}
    end
  end

  defp calculate_withdrawal(pool, lp_amount, :balanced) do
    total_usd = Float.round(lp_amount * pool.virtual_price, 6)
    total_bal = Enum.sum(pool.balances)

    withdrawn =
      Enum.zip(pool.coins, pool.balances)
      |> Map.new(fn {coin, bal} ->
        share = if total_bal > 0, do: bal / total_bal, else: 1.0 / length(pool.coins)
        {coin, Float.round(total_usd * share, 6)}
      end)

    {:ok, withdrawn, total_usd}
  end

  defp calculate_withdrawal(pool, lp_amount, {:one_coin, coin}) do
    case coin_index(pool, coin) do
      {:ok, _idx} ->
        gross_usd = lp_amount * pool.virtual_price
        fee_factor = 1.0 - pool.fee_bps * 0.5 / @basis_points
        net_usd = Float.round(gross_usd * fee_factor, 6)
        {:ok, %{coin => net_usd}, net_usd}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp calculate_vecrv_boost(staked_lp, pool_tvl_usd, vecrv_balance, total_vecrv) do
    if vecrv_balance <= 0 or total_vecrv <= 0 or pool_tvl_usd <= 0 do
      1.0
    else
      vote_share = vecrv_balance / total_vecrv
      liquidity_share = staked_lp / pool_tvl_usd
      raw_boost = 1.0 + 1.5 * (vote_share / max(liquidity_share, 1.0e-9))
      Float.round(min(2.5, max(1.0, raw_boost)), 4)
    end
  end

  defp chain_match?(_pool, nil), do: true
  defp chain_match?(pool, chain), do: pool.chain == chain

  defp type_match?(_pool, nil), do: true
  defp type_match?(pool, pool_type), do: pool.pool_type == pool_type

  defp coin_match?(_pool, nil), do: true
  defp coin_match?(pool, coin), do: coin in pool.coins

  defp all_pools_map do
    Map.merge(@default_pools, get_state(:custom_pools, %{}))
  end

  defp get_wallet_positions(wallet) do
    positions = get_state(:positions, %{})
    Map.get(positions, wallet, %{})
  end

  defp get_lp_balance(wallet, pool_id) do
    wallet
    |> get_wallet_positions()
    |> Map.get(pool_id, %{lp_balance: 0.0, gauge_staked: 0.0})
    |> Map.get(:lp_balance, 0.0)
  end

  defp get_gauge_stake(wallet, pool_id) do
    wallet
    |> get_wallet_positions()
    |> Map.get(pool_id, %{lp_balance: 0.0, gauge_staked: 0.0})
    |> Map.get(:gauge_staked, 0.0)
  end

  defp update_lp_position(wallet, pool_id, delta) do
    positions = get_state(:positions, %{})
    wallet_pos = Map.get(positions, wallet, %{})
    current = Map.get(wallet_pos, pool_id, %{lp_balance: 0.0, gauge_staked: 0.0})
    new_lp = Float.round(max(0.0, current.lp_balance + delta), 6)
    updated_pool_pos = %{current | lp_balance: new_lp}

    put_state(
      :positions,
      Map.put(positions, wallet, Map.put(wallet_pos, pool_id, updated_pool_pos))
    )

    new_lp
  end

  defp update_gauge_stake(wallet, pool_id, delta) do
    positions = get_state(:positions, %{})
    wallet_pos = Map.get(positions, wallet, %{})
    current = Map.get(wallet_pos, pool_id, %{lp_balance: 0.0, gauge_staked: 0.0})
    new_staked = Float.round(max(0.0, current.gauge_staked + delta), 6)
    updated_pool_pos = %{current | gauge_staked: new_staked}

    put_state(
      :positions,
      Map.put(positions, wallet, Map.put(wallet_pos, pool_id, updated_pool_pos))
    )

    new_staked
  end

  defp generate_tx_hash(payload) do
    hash =
      :crypto.hash(:sha256, :erlang.term_to_binary({payload, System.unique_integer()}))
      |> Base.encode16(case: :lower)

    "0x" <> hash
  end

  defp ensure_table! do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])

      _tid ->
        :ok
    end
  end

  defp get_state(key, default) do
    ensure_table!()

    case :ets.lookup(@table, key) do
      [{^key, val}] -> val
      [] -> default
    end
  end

  defp put_state(key, val) do
    ensure_table!()
    :ets.insert(@table, {key, val})
    :ok
  end
end
