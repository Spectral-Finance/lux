defmodule Lux.Integrations.PancakeSwap.Farming do
  @moduledoc """
  Deterministic PancakeSwap yield farming, compounding, and risk helpers.
  """

  alias Lux.Integrations.PancakeSwap

  @default_slippage_bps 50
  @default_deadline_seconds 1_200

  @doc "Normalizes farm pool rows and ranks by risk-adjusted APR."
  def normalize_pools(rows, opts \\ %{}) when is_list(rows) do
    rows
    |> Enum.map(&pool_summary(&1, opts))
    |> Enum.sort_by(& &1.risk_adjusted_apr, :desc)
  end

  @doc "Normalizes one liquidity/farming position."
  def position(attrs, opts \\ %{}) do
    pool = value(attrs, :pool) || %{}
    chain = value(attrs, :chain) || value(pool, :chain) || value(opts, :chain)
    total_apr = first_number(attrs, [:total_apr, :apr]) || total_apr(attrs, pool)
    liquidity_usd = first_number(attrs, [:liquidity_usd, :value_usd, :tvl_usd]) || 0.0

    %{
      id: value(attrs, :id) || value(attrs, :token_id),
      owner: value(attrs, :owner) || value(attrs, :user),
      chain: chain,
      pool_id: value(attrs, :pool_id) || value(pool, :id) || value(attrs, :pid),
      token_id: value(attrs, :token_id),
      token0: value(attrs, :token0) || value(pool, :token0),
      token1: value(attrs, :token1) || value(pool, :token1),
      liquidity_usd: liquidity_usd,
      staked: default_bool(attrs, :staked, false),
      price_in_range: default_bool(attrs, :price_in_range, true),
      pending_reward_usd: number(attrs, :pending_reward_usd),
      pending_reward_amount: number(attrs, :pending_reward_amount),
      reward_token: value(attrs, :reward_token) || "CAKE",
      fee_apr: first_number(attrs, [:fee_apr, :lp_apr]) || number(pool, :fee_apr),
      farming_apr: first_number(attrs, [:farming_apr, :reward_apr]) || number(pool, :reward_apr),
      total_apr: total_apr,
      impermanent_loss_pct: abs(number(attrs, :impermanent_loss_pct)),
      gas_cost_usd: number(attrs, :gas_cost_usd),
      risk_score: risk_score(attrs, pool, opts)
    }
  end

  @doc "Builds a pool add-liquidity and optional stake plan."
  def add_liquidity_plan(pool, token_amounts, opts \\ %{}) do
    pool = pool_summary(pool, opts)
    stake? = default_bool(opts, :stake, true)

    steps =
      [
        %{action: :approve_token, token: pool.token0, amount: value(token_amounts, :token0)},
        %{action: :approve_token, token: pool.token1, amount: value(token_amounts, :token1)},
        %{
          action: :add_liquidity,
          chain: pool.chain,
          pool_id: pool.id,
          token_amounts: token_amounts,
          slippage_bps: integer(opts, :slippage_bps, @default_slippage_bps),
          deadline_seconds: integer(opts, :deadline_seconds, @default_deadline_seconds)
        }
      ] ++ if(stake?, do: [%{action: :stake_position, farm: :masterchef_v3}], else: [])

    %{type: :add_liquidity, chain: pool.chain, pool_id: pool.id, status: :ready, steps: steps}
  end

  @doc "Builds an unstake/remove-liquidity plan."
  def remove_liquidity_plan(position, opts \\ %{}) do
    position = position(position, opts)

    %{
      type: :remove_liquidity,
      chain: position.chain,
      pool_id: position.pool_id,
      token_id: position.token_id,
      status: :ready,
      steps: [
        %{action: :unstake_position, token_id: position.token_id},
        %{
          action: :remove_liquidity,
          token_id: position.token_id,
          share_bps: integer(opts, :share_bps, 10_000),
          slippage_bps: integer(opts, :slippage_bps, @default_slippage_bps)
        },
        %{action: :collect_fees, token_id: position.token_id}
      ]
    }
  end

  @doc "Builds a CAKE harvest plan."
  def harvest_plan(position, opts \\ %{}) do
    position = position(position, opts)

    %{
      type: :harvest,
      chain: position.chain,
      pool_id: position.pool_id,
      token_id: position.token_id,
      status: :ready,
      expected_reward_usd: position.pending_reward_usd,
      steps: [
        %{
          action: :harvest_rewards,
          token_id: position.token_id,
          reward_token: position.reward_token,
          recipient: value(opts, :recipient) || position.owner
        }
      ]
    }
  end

  @doc "Builds an auto-compound plan when pending rewards justify gas/slippage."
  def compound_plan(position, opts \\ %{}) do
    position = position(position, opts)
    min_reward_usd = number(opts, :min_reward_usd)
    gas_cost_usd = default_number(opts, :gas_cost_usd, position.gas_cost_usd)
    reinvest_pct = default_number(opts, :reinvest_pct, 100.0)
    slippage_bps = integer(opts, :slippage_bps, @default_slippage_bps)

    cond do
      position.pending_reward_usd < min_reward_usd ->
        skipped_compound(position, :below_reward_threshold)

      position.pending_reward_usd <= gas_cost_usd ->
        skipped_compound(position, :gas_cost_exceeds_reward)

      not position.price_in_range ->
        skipped_compound(position, :position_out_of_range)

      true ->
        reinvest_usd = position.pending_reward_usd * reinvest_pct / 100.0

        %{
          type: :auto_compound,
          chain: position.chain,
          pool_id: position.pool_id,
          token_id: position.token_id,
          status: :ready,
          reinvest_usd: Float.round(reinvest_usd, 2),
          expected_net_reward_usd: Float.round(position.pending_reward_usd - gas_cost_usd, 2),
          steps: [
            %{
              action: :harvest_rewards,
              token_id: position.token_id,
              reward_token: position.reward_token
            },
            %{
              action: :swap_reward_to_pool_tokens,
              reward_token: position.reward_token,
              slippage_bps: slippage_bps
            },
            %{
              action: :increase_liquidity,
              token_id: position.token_id,
              reinvest_usd: Float.round(reinvest_usd, 2)
            },
            %{action: :stake_position, farm: :masterchef_v3}
          ]
        }
    end
  end

  @doc "Ranks pools by APR after risk, TVL, and chain filters."
  def optimize_pools(pools, opts \\ %{}) do
    chain = value(opts, :chain)
    min_tvl_usd = number(opts, :min_tvl_usd)
    max_risk_score = default_number(opts, :max_risk_score, 100.0)

    pools
    |> normalize_pools(opts)
    |> Enum.filter(&(is_nil(chain) or to_string(&1.chain) == to_string(chain)))
    |> Enum.filter(&(&1.tvl_usd >= min_tvl_usd))
    |> Enum.filter(&(&1.risk_score <= max_risk_score))
  end

  @doc "Returns risk flags for a position."
  def risk_report(position, opts \\ %{}) do
    position = position(position, opts)
    min_liquidity_usd = default_number(opts, :min_liquidity_usd, 100_000.0)
    max_il_pct = default_number(opts, :max_impermanent_loss_pct, 10.0)
    min_net_reward_usd = default_number(opts, :min_net_reward_usd, 0.0)
    net_reward_usd = position.pending_reward_usd - position.gas_cost_usd

    flags =
      []
      |> add_flag(
        not position.price_in_range,
        :out_of_range,
        :high,
        "position outside active tick range"
      )
      |> add_flag(
        position.impermanent_loss_pct > max_il_pct,
        :impermanent_loss,
        :medium,
        "impermanent loss above limit"
      )
      |> add_flag(
        position.liquidity_usd < min_liquidity_usd,
        :low_liquidity,
        :medium,
        "position value below liquidity floor"
      )
      |> add_flag(
        net_reward_usd < min_net_reward_usd,
        :uneconomic_harvest,
        :low,
        "pending reward does not justify harvest"
      )

    %{risk_score: position.risk_score, flags: Enum.reverse(flags)}
  end

  @doc "Builds a deterministic cross-chain migration plan."
  def bridge_plan(position, target_chain, opts \\ %{}) do
    position = position(position, opts)

    with {:ok, source_chain} <- PancakeSwap.chain(position.chain),
         {:ok, target_chain} <- PancakeSwap.chain(target_chain) do
      %{
        type: :cross_chain_migration,
        status: if(source_chain.key == target_chain.key, do: :skip, else: :ready),
        source_chain: source_chain.key,
        target_chain: target_chain.key,
        pool_id: position.pool_id,
        token_id: position.token_id,
        bridge: value(opts, :bridge) || :external_bridge,
        steps: [
          %{action: :unstake_position, chain: source_chain.key, token_id: position.token_id},
          %{action: :remove_liquidity, chain: source_chain.key, token_id: position.token_id},
          %{action: :bridge_assets, from_chain: source_chain.key, to_chain: target_chain.key},
          %{action: :add_liquidity, chain: target_chain.key},
          %{action: :stake_position, chain: target_chain.key, farm: :masterchef_v3}
        ]
      }
    end
  end

  defp pool_summary(row, opts) do
    fee_apr = first_number(row, [:fee_apr, :lp_apr]) || 0.0
    reward_apr = first_number(row, [:reward_apr, :farming_apr, :cake_apr]) || 0.0
    total_apr = first_number(row, [:total_apr, :apr]) || fee_apr + reward_apr
    risk_score = risk_score(row, %{}, opts)

    %{
      id: value(row, :id) || value(row, :pool_id),
      pid: value(row, :pid),
      chain: value(row, :chain) || value(opts, :chain),
      token0: token_symbol(value(row, :token0)),
      token1: token_symbol(value(row, :token1)),
      fee: number(row, :fee),
      tvl_usd: first_number(row, [:tvl_usd, :liquidity_usd, :totalLiquidity]) || 0.0,
      total_boost_liquidity: number(row, :totalBoostLiquidity),
      fee_apr: fee_apr,
      reward_apr: reward_apr,
      total_apr: total_apr,
      risk_score: risk_score,
      risk_adjusted_apr: Float.round(total_apr * (1.0 - min(risk_score, 100.0) / 100.0), 2)
    }
  end

  defp risk_score(attrs, pool, opts) do
    max_il_pct = default_number(opts, :max_impermanent_loss_pct, 10.0)
    min_tvl_usd = default_number(opts, :min_tvl_usd, 100_000.0)
    tvl = first_number(attrs, [:tvl_usd, :liquidity_usd]) || number(pool, :tvl_usd)

    0.0
    |> add_score(default_bool(attrs, :price_in_range, true) == false, 35.0)
    |> add_score(abs(number(attrs, :impermanent_loss_pct)) > max_il_pct, 25.0)
    |> add_score(tvl < min_tvl_usd, 20.0)
    |> add_score(number(attrs, :gas_cost_usd) > number(attrs, :pending_reward_usd), 10.0)
  end

  defp total_apr(attrs, pool) do
    number(attrs, :fee_apr) + number(attrs, :farming_apr) + number(pool, :fee_apr) +
      number(pool, :reward_apr)
  end

  defp skipped_compound(position, reason) do
    %{
      type: :auto_compound,
      chain: position.chain,
      pool_id: position.pool_id,
      token_id: position.token_id,
      status: :skip,
      reason: reason,
      steps: []
    }
  end

  defp add_score(score, true, amount), do: score + amount
  defp add_score(score, false, _amount), do: score

  defp add_flag(flags, true, type, severity, message),
    do: [%{type: type, severity: severity, message: message} | flags]

  defp add_flag(flags, false, _type, _severity, _message), do: flags

  defp token_symbol(%{symbol: symbol}), do: symbol
  defp token_symbol(%{"symbol" => symbol}), do: symbol
  defp token_symbol(symbol) when is_binary(symbol), do: symbol
  defp token_symbol(nil), do: nil
  defp token_symbol(token), do: inspect(token)

  defp default_bool(map, key, default) do
    case value(map, key) do
      nil -> default
      value -> value in [true, "true", 1, "1", true]
    end
  end

  defp default_number(map, key, default) do
    case value(map, key) do
      nil -> default
      value -> number_value(value)
    end
  end

  defp integer(map, key, default), do: round(default_number(map, key, default))

  defp first_number(map, keys) do
    keys
    |> Enum.map(&number(map, &1))
    |> Enum.find(&(&1 != 0.0))
  end

  defp number(map, key), do: value(map, key) |> number_value()
  defp number_value(nil), do: 0.0
  defp number_value(value) when is_integer(value), do: value * 1.0
  defp number_value(value) when is_float(value), do: value
  defp number_value(value) when is_binary(value), do: value |> Float.parse() |> elem_or_zero()
  defp number_value(_value), do: 0.0
  defp elem_or_zero({number, _rest}), do: number
  defp elem_or_zero(:error), do: 0.0

  defp value(map, key) when is_map(map) do
    cond do
      Map.has_key?(map, key) -> Map.fetch!(map, key)
      Map.has_key?(map, to_string(key)) -> Map.fetch!(map, to_string(key))
      true -> nil
    end
  end

  defp value(data, key) when is_list(data), do: Keyword.get(data, key)
  defp value(_map, _key), do: nil
end
