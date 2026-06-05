defmodule Lux.Integrations.PancakeSwap do
  @moduledoc """
  PancakeSwap DEX integration — provides yield farming info, LP calculations,
  and cross-chain data access via the BNB Chain (and extended chains).

  Supports:
  - Pool queries (via TheGraph)
  - Yield farming APRs and reward rates
  - Liquidity provision calculations
  - Cross-chain data aggregation
  """

  @base_url "https://api.thegraph.com/subgraphs/name/pancakeswap/exchange-v3"
  @masterchef_url "https://api.thegraph.com/subgraphs/name/pancakeswap/masterchef-v2"

  @doc """
  Queries pools from the PancakeSwap subgraph with optional filters.
  """
  def query_pools(filters \\ %{}) do
    query = build_pools_query(filters)

    case post_graphql(@base_url, query) do
      {:ok, %{"data" => %{"pools" => pools}}} ->
        {:ok, Enum.map(pools, &format_pool/1)}

      {:ok, %{"data" => data}} ->
        {:ok, format_pool(data)}

      {:ok, %{"errors" => errors}} ->
        {:error, errors}

      error ->
        error
    end
  end

  @doc """
  Queries tokens from the PancakeSwap subgraph.
  """
  def query_tokens(filters \\ %{}) do
    query = build_tokens_query(filters)

    case post_graphql(@base_url, query) do
      {:ok, %{"data" => %{"tokens" => tokens}}} ->
        {:ok, Enum.map(tokens, &format_token/1)}

      {:ok, %{"errors" => errors}} ->
        {:error, errors}

      error ->
        error
    end
  end

  # ── Yield Farming ─────────────────────────────────────────────────────────

  @doc """
  Gets yield farming information for a specific pool or all pools.
  Returns pool APRs, reward rates, and staking information.
  """
  def get_yield_farming(pool_id \\ nil) do
    query = build_farming_query(pool_id)

    case post_graphql(@masterchef_url, query) do
      {:ok, %{"data" => %"pools" => pools}} when is_list(pools) ->
        {:ok, Enum.map(pools, &format_farm_pool/1)}

      {:ok, %{"data" => data}} ->
        {:ok, format_farm_pool(data)}

      {:ok, %{"errors" => errors}} ->
        {:error, errors}

      error ->
        error
    end
  end

  @doc """
  Calculates estimated APR for a PancakeSwap liquidity pool.
  """
  def calculate_pool_apr(pool_id, opts \\ []) do
    case get_pool_volume_24h(pool_id) do
      {:ok, volume_24h} ->
        fee_tier = Keyword.get(opts, :fee_tier, 0.0025)
        tvl = Keyword.get(opts, :tvl, 0)
        cake_price = Keyword.get(opts, :cake_price, 0)

        fee_revenue = volume_24h * fee_tier
        annualized_fees = fee_revenue * 365
        base_apr = if tvl > 0, do: annualized_fees / tvl, else: 0

        cake_rewards = Keyword.get(opts, :cake_rewards_per_day, 0)
        reward_apr = if tvl > 0 && cake_price > 0, do: (cake_rewards * cake_price * 365) / tvl, else: 0

        {:ok, %{
          pool_id: pool_id,
          fee_apr: Float.round(base_apr * 100, 2),
          reward_apr: Float.round(reward_apr * 100, 2),
          total_apr: Float.round((base_apr + reward_apr) * 100, 2),
          volume_24h: volume_24h,
          tvl: tvl
        }}

      error ->
        error
    end
  end

  @doc """
  Gets the daily reward rate for a given farm pool.
  """
  def get_reward_rate(pool_id, cake_price \\ 0) do
    case get_yield_farming(pool_id) do
      {:ok, farm} when is_map(farm) ->
        reward_per_block = Map.get(farm, :reward_per_block, 0)
        blocks_per_day = 28_800  # ~3 second blocks on BSC
        daily_rewards = reward_per_block * blocks_per_day
        daily_reward_usd = daily_rewards * cake_price

        {:ok, %{
          pool_id: pool_id,
          reward_per_block: reward_per_block,
          blocks_per_day: blocks_per_day,
          daily_rewards_tokens: daily_rewards,
          daily_rewards_usd: daily_reward_usd
        }}

      {:ok, _} ->
        {:error, "Farm pool not found: #{pool_id}"}

      error ->
        error
    end
  end

  # ── Liquidity Provision ───────────────────────────────────────────────────

  @doc """
  Calculates liquidity provision details for a given pool and deposit amount.
  """
  def calculate_lp(deposit_token_a, deposit_token_b, pool_id, opts \\ []) do
    deposit_a = parse_amount(deposit_token_a)
    deposit_b = parse_amount(deposit_token_b)

    case get_pool_info(pool_id) do
      {:ok, pool} ->
        total_liquidity = Map.get(pool, :total_liquidity, 1)
        pool_tvl = Map.get(pool, :tvl, 0)

        share_of_pool = (deposit_a + deposit_b) / (total_liquidity + deposit_a + deposit_b)
        estimated_fee_share = share_of_pool * Map.get(pool, :volume_24h, 0) * 0.0025

        slippage = Keyword.get(opts, :slippage, 0.005)
        min_lp_tokens = share_of_pool * (1 - slippage)

        {:ok, %{
          deposit_token_a: deposit_a,
          deposit_token_b: deposit_b,
          pool_share_pct: Float.round(share_of_pool * 100, 6),
          estimated_lp_tokens: share_of_pool * total_liquidity,
          min_lp_tokens: min_lp_tokens * total_liquidity,
          estimated_daily_fees: estimated_fee_share,
          estimated_annual_fees: estimated_fee_share * 365,
          pool_volume_24h: Map.get(pool, :volume_24h, 0),
          pool_tvl: pool_tvl
        }}

      error ->
        error
    end
  end

  @doc """
  Estimates returns for providing liquidity over a given period.
  """
  def estimate_lp_returns(pool_id, deposit_a, deposit_b, days \\ 30, opts \\ []) do
    with {:ok, lp_details} <- calculate_lp(deposit_a, deposit_b, pool_id, opts),
         daily_fees = Map.get(lp_details, :estimated_daily_fees, 0),
         period_fees = daily_fees * days,
         impermanent_loss = Keyword.get(opts, :impermanent_loss, 0),
         net_return = period_fees * (1 - impermanent_loss) do
      {:ok, %{
        pool_id: pool_id,
        deposit_total: Map.get(lp_details, :deposit_token_a, 0) + Map.get(lp_details, :deposit_token_b, 0),
        pool_share_pct: Map.get(lp_details, :pool_share_pct),
        period_days: days,
        estimated_fees: period_fees,
        estimated_net_return: net_return,
        estimated_apr: Float.round((net_return / (Map.get(lp_details, :deposit_token_a, 0) + Map.get(lp_details, :deposit_token_b, 0))) * (365 / days) * 100, 2),
        impermanent_loss_applied: impermanent_loss > 0
      }}
    end
  end

  # ── Cross-Chain Data ──────────────────────────────────────────────────────

  @supported_chains %{
    bsc: "https://api.thegraph.com/subgraphs/name/pancakeswap/exchange-v3",
    ethereum: "https://api.thegraph.com/subgraphs/name/pancakeswap/exchange-v3-eth",
    arbitrum: "https://api.thegraph.com/subgraphs/name/pancakeswap/exchange-v3-arbitrum",
    opbnb: "https://api.thegraph.com/subgraphs/name/pancakeswap/exchange-v3-opbnb",
    polygon_zkevm: "https://api.thegraph.com/subgraphs/name/pancakeswap/exchange-v3-polygon-zkevm"
  }

  @doc """
  Gets cross-chain pool data by querying configured chain endpoints.
  """
  def get_cross_chain_pools(chains \\ [:bsc]) do
    chains
    |> Enum.map(fn chain ->
      url = Map.get(@supported_chains, chain)

      case url do
        nil ->
          {chain, {:error, "Unsupported chain: #{chain}"}}

        url ->
          query = build_pools_query(%{first: 10})

          case post_graphql(url, query) do
            {:ok, %{"data" => %{"pools" => pools}}} ->
              {chain, {:ok, Enum.map(pools, &format_pool/1)}}

            {:ok, %{"errors" => errors}} ->
              {chain, {:error, errors}}

            error ->
              {chain, error}
          end
      end
    end)
    |> Enum.into(%{})
  end

  @doc """
  Aggregates pool data across multiple chains.
  """
  def aggregate_cross_chain(chains \\ [:bsc, :ethereum]) do
    chain_data = get_cross_chain_pools(chains)

    total_pools =
      chain_data
      |> Enum.reduce(0, fn {_chain, {:ok, pools}}, acc -> acc + length(pools); {_, _}, acc -> acc end)

    total_volume =
      chain_data
      |> Enum.reduce(0, fn
        {_chain, {:ok, pools}}, acc ->
          acc + Enum.reduce(pools, 0, &(&2 + Map.get(&1, :volume_usd, 0)))
        {_, _}, acc -> acc
      end)

    total_tvl =
      chain_data
      |> Enum.reduce(0, fn
        {_chain, {:ok, pools}}, acc ->
          acc + Enum.reduce(pools, 0, &(&2 + Map.get(&1, :tvl_usd, 0)))
        {_, _}, acc -> acc
      end)

    {:ok, %{
      chains_queried: chains,
      total_pools: total_pools,
      total_volume_24h: total_volume,
      total_tvl: total_tvl,
      chain_details: chain_data
    }}
  end

  # ── Helpers ───────────────────────────────────────────────────────────────

  defp post_graphql(url, query) do
    case Req.post(url, json: %{query: query}, receive_timeout: 30_000) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, "HTTP #{status}: #{inspect(body)}"}
      {:error, reason} -> {:error, reason}
    end
  rescue
    e -> {:error, "GraphQL request failed: #{Exception.message(e)}"}
  end

  defp build_pools_query(filters) do
    first = Map.get(filters, :first, 50)
    skip = Map.get(filters, :skip, 0)
    order_by = Map.get(filters, :order_by, "totalValueLockedUSD")
    order_direction = Map.get(filters, :order_direction, "desc")

    """
    {
      pools(first: #{first}, skip: #{skip}, orderBy: #{order_by}, orderDirection: #{order_direction}) {
        id
        token0 { id symbol name decimals }
        token1 { id symbol name decimals }
        feeTier
        liquidity
        sqrtPrice
        volumeUSD
        totalValueLockedUSD
        txCount
      }
    }
    """
  end

  defp build_tokens_query(filters) do
    first = Map.get(filters, :first, 50)

    """
    {
      tokens(first: #{first}) {
        id
        symbol
        name
        decimals
        volume
        totalValueLocked
        txCount
      }
    }
    """
  end

  defp build_farming_query(pool_id) do
    id_filter = if pool_id, do: "(id: #{pool_id})", else: "(first: 50)"

    """
    {
      pools #{id_filter} {
        id
        pair
        allocPoint
        lastRewardBlock
        accCakePerShare
        rewarder {
          rewardPerSecond
          rewardToken
        }
      }
    }
    """
  end

  defp format_pool(pool) do
    %{
      id: Map.get(pool, "id"),
      token0: format_token(Map.get(pool, "token0", %{})),
      token1: format_token(Map.get(pool, "token1", %{})),
      fee_tier: parse_float(Map.get(pool, "feeTier")),
      liquidity: parse_float(Map.get(pool, "liquidity")),
      sqrt_price: Map.get(pool, "sqrtPrice"),
      volume_usd: parse_float(Map.get(pool, "volumeUSD")),
      tvl_usd: parse_float(Map.get(pool, "totalValueLockedUSD")),
      tx_count: parse_int(Map.get(pool, "txCount"))
    }
  end

  defp format_token(token) do
    %{
      id: Map.get(token, "id"),
      symbol: Map.get(token, "symbol"),
      name: Map.get(token, "name"),
      decimals: parse_int(Map.get(token, "decimals")),
      volume: parse_float(Map.get(token, "volume")),
      tvl: parse_float(Map.get(token, "totalValueLocked")),
      tx_count: parse_int(Map.get(token, "txCount"))
    }
  end

  defp format_farm_pool(pool) do
    rewarder = Map.get(pool, "rewarder", %{})

    %{
      id: Map.get(pool, "id"),
      pair: Map.get(pool, "pair"),
      alloc_point: parse_int(Map.get(pool, "allocPoint")),
      last_reward_block: parse_int(Map.get(pool, "lastRewardBlock")),
      acc_cake_per_share: Map.get(pool, "accCakePerShare"),
      reward_per_second: parse_float(Map.get(rewarder, "rewardPerSecond")),
      reward_token: Map.get(rewarder, "rewardToken")
    }
  end

  defp get_pool_volume_24h(pool_id) do
    query = """
    {
      poolDayDatas(first: 1, where: {pool: "#{pool_id}"}, orderBy: date, orderDirection: desc) {
        volumeUSD
      }
    }
    """

    case post_graphql(@base_url, query) do
      {:ok, %{"data" => %{"poolDayDatas" => [day_data | _]}}} ->
        {:ok, parse_float(Map.get(day_data, "volumeUSD"))}

      {:ok, %{"data" => %{"poolDayDatas" => []}}} ->
        {:ok, 0}

      error ->
        error
    end
  end

  defp get_pool_info(pool_id) do
    query = """
    {
      pool(id: "#{pool_id}") {
        id
        liquidity
        volumeUSD
        totalValueLockedUSD
        token0 { symbol }
        token1 { symbol }
      }
    }
    """

    case post_graphql(@base_url, query) do
      {:ok, %{"data" => %{"pool" => pool}}} when not is_nil(pool) ->
        {:ok, %{
          id: Map.get(pool, "id"),
          total_liquidity: parse_float(Map.get(pool, "liquidity")),
          volume_24h: parse_float(Map.get(pool, "volumeUSD")),
          tvl: parse_float(Map.get(pool, "totalValueLockedUSD"))
        }}

      {:ok, _} ->
        {:error, "Pool not found: #{pool_id}"}

      error ->
        error
    end
  end

  defp parse_amount(amount) when is_number(amount), do: amount
  defp parse_amount(amount) when is_binary(amount), do: String.to_integer(amount)
  defp parse_amount(_), do: 0

  defp parse_float(nil), do: 0.0
  defp parse_float(val) when is_number(val), do: val / 1
  defp parse_float(val) when is_binary(val), do: String.to_float(val)
  defp parse_float(_), do: 0.0

  defp parse_int(nil), do: 0
  defp parse_int(val) when is_integer(val), do: val
  defp parse_int(val) when is_binary(val), do: String.to_integer(val)
  defp parse_int(_), do: 0
end
