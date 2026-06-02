defmodule Lux.Integrations.PancakeSwap.Pools do
  @moduledoc """
  Liquidity pool management for PancakeSwap.

  Handles pool discovery, detailed pool analysis, and APY tracking
  across multiple chains via the PancakeSwap subgraph.
  """

  require Logger

  alias Lux.Integrations.PancakeSwap.Client

  @doc """
  Lists available liquidity pools for a given chain.

  ## Options
  - `:chain_id` - Chain ID to query (default from config)
  - `:limit` - Maximum pools to return (default: 50)
  - `:order_by` - Sort field (default: "reserveUSD")
  - `:order_direction` - Sort direction (default: "desc")
  - `:min_liquidity` - Minimum USD liquidity (default: 10000)
  """
  @spec list_pools(keyword()) :: {:ok, [map()]} | {:error, String.t()}
  def list_pools(opts \\ []) do
    chain_id = Keyword.get(opts, :chain_id, 56)
    limit = Keyword.get(opts, :limit, 50)
    order_by = Keyword.get(opts, :order_by, "reserveUSD")
    order_direction = Keyword.get(opts, :order_direction, "desc")
    min_liquidity = Keyword.get(opts, :min_liquidity, 10_000)

    chain_slug = Client.chain_slug(chain_id)

    query = ~s"""
    {
      pools(
        first: #{limit},
        orderBy: #{order_by},
        orderDirection: #{order_direction},
        where: { totalValueLockedUSD_gte: "#{min_liquidity}" }
      ) {
        id
        token0 { symbol name decimals }
        token1 { symbol name decimals }
        feeTier
        totalValueLockedUSD
        volumeUSD
        untrackedVolumeUSD
        txCount
        poolDayData(first: 1, orderBy: date, orderDirection: desc) {
          tvlUSD
          volumeUSD
          feesUSD
          date
        }
      }
    }
    """

    with {:ok, %{"pools" => pools}} <- Client.subgraph_query(chain_slug, query) do
      enriched =
        pools
        |> Enum.map(&enrich_pool_data/1)
        |> Enum.sort_by(& &1["tvl_usd"], :desc)

      {:ok, enriched}
    end
  end

  @doc """
  Gets detailed information about a specific pool by its ID.
  """
  @spec get_pool(String.t() | non_neg_integer(), keyword()) ::
          {:ok, map()} | {:error, String.t()}
  def get_pool(pool_id, opts \\ []) do
    chain_id = Keyword.get(opts, :chain_id, 56)
    chain_slug = Client.chain_slug(chain_id)

    query = """
    {
      pool(id: "#{pool_id}") {
        id
        token0 { symbol name decimals derivedETH }
        token1 { symbol name decimals derivedETH }
        feeTier
        liquidity
        sqrtPrice
        tick
        totalValueLockedUSD
        totalValueLockedToken0
        totalValueLockedToken1
        volumeUSD
        feesUSD
        untrackedVolumeUSD
        txCount
        createdAtTimestamp
        poolDayData(first: 7, orderBy: date, orderDirection: desc) {
          date
          tvlUSD
          volumeUSD
          feesUSD
          token0Price
          token1Price
        }
        poolHourData(first: 24, orderBy: periodStartUnix, orderDirection: desc) {
          periodStartUnix
          tvlUSD
          volumeUSD
          feesUSD
        }
      }
    }
    """

    with {:ok, %{"pool" => pool}} when not is_nil(pool) <-
           Client.subgraph_query(chain_slug, query) do
      enriched = enrich_pool_data(pool) |> Map.put("chain_id", chain_id)
      {:ok, enriched}
    else
      {:ok, %{"pool" => nil}} -> {:error, "Pool not found: #{pool_id}"}
      error -> error
    end
  end

  @doc """
  Gets the current APY for a farming pool based on recent fees and TVL.
  """
  @spec get_apy(String.t() | non_neg_integer(), keyword()) ::
          {:ok, float()} | {:error, String.t()}
  def get_apy(pool_id, opts \\ []) do
    with {:ok, pool} <- get_pool(pool_id, opts) do
      apy = calculate_apy(pool)
      {:ok, apy}
    end
  end

  defp enrich_pool_data(pool) do
    token0 = pool["token0"] || %{}
    token1 = pool["token1"] || %{}
    tvl_usd = parse_float(pool["totalValueLockedUSD"])
    volume_usd = parse_float(pool["volumeUSD"])
    fees_usd = parse_float(pool["feesUSD"])

    pool
    |> Map.put("pair", "#{token0["symbol"]}/#{token1["symbol"]}")
    |> Map.put("token0_symbol", token0["symbol"])
    |> Map.put("token1_symbol", token1["symbol"])
    |> Map.put("tvl_usd", tvl_usd)
    |> Map.put("volume_usd", volume_usd)
    |> Map.put("fees_usd", fees_usd)
    |> Map.put("fee_tier", pool["feeTier"] || "0.25%")
    |> Map.put("fee_tier_pct", parse_fee_tier(pool["feeTier"]))
    |> Map.put("apr", calculate_apr(tvl_usd, volume_usd, parse_fee_tier(pool["feeTier"])))
    |> Map.put("apy", calculate_apy(pool))
  end

  defp calculate_apr(tvl_usd, volume_usd, fee_tier_pct)
       when tvl_usd > 0 and volume_usd > 0 do
    daily_fees = volume_usd * fee_tier_pct
    (daily_fees * 365.0 / tvl_usd) * 100.0
  end

  defp calculate_apr(_, _, _), do: 0.0

  defp calculate_apy(pool) when is_map(pool) do
    apr = calculate_apr(
      parse_float(pool["totalValueLockedUSD"] || pool["tvl_usd"]),
      parse_float(pool["volumeUSD"] || pool["volume_usd"]),
      parse_fee_tier(pool["feeTier"])
    )

    if apr > 0 do
      daily_rate = apr / 100.0 / 365.0
      (100.0 * (:math.exp(daily_rate * 365) - 1))
    else
      0.0
    end
  end

  defp parse_float(nil), do: 0.0
  defp parse_float(val) when is_float(val), do: val

  defp parse_float(val) when is_binary(val) do
    case Float.parse(val) do
      {f, _} -> f
      :error -> 0.0
    end
  end

  defp parse_float(val) when is_number(val), do: val / 1

  defp parse_fee_tier(nil), do: 0.0025

  defp parse_fee_tier(fee) when is_binary(fee) do
    case Integer.parse(fee) do
      {tier, _} -> tier / 1_000_000.0
      :error -> 0.0025
    end
  end

  defp parse_fee_tier(_), do: 0.0025
end
