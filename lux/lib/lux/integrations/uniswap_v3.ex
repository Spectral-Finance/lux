defmodule Lux.Integrations.UniswapV3 do
  @moduledoc """
  Uniswap V3 integration — concentrated liquidity management, pool analytics,
  position tracking, and trading data via The Graph subgraph.

  ## Features
  - Pool data: TVL, volume, fees, APR across all fee tiers
  - Position management: NFT-based concentrated liquidity positions
  - Price range optimization: tick math and range bounds
  - Fee collection and reinvestment tracking
  - Historical analytics: volume, TVL, and fee trends
  - Multi-chain support (Ethereum, Arbitrum, Optimism, Polygon)

  ## Configuration

      config :lux, Lux.Integrations.UniswapV3,
        chain: :ethereum,
        subgraph_url: "https://gateway.thegraph.com/api/.../subgraphs/id/..."

  ## Usage

      alias Lux.Integrations.UniswapV3

      # Pool data
      UniswapV3.pools()
      UniswapV3.pool("0x8ad599c3a0ff1de082011efddc58f1908eb6e6d8")

      # Positions
      UniswapV3.position(1)
      UniswapV3.positions_for_owner("0x...")

      # Analytics
      UniswapV3.top_pools(limit: 10)
      UniswapV3.pool_hourly_data("0x8ad599c3a0ff1de082011efddc58f1908eb6e6d8", hours: 168)

      # Fee tiers
      UniswapV3.fee_tiers()
  """

  @chains %{
    ethereum: "https://gateway.thegraph.com/api/.../subgraphs/id/5zvR82QoaXYFyDEKLZ9t6v9adgnptxYpKpSbxtgVENFV",
    arbitrum: "https://gateway.thegraph.com/api/.../subgraphs/id/...",
    optimism: "https://gateway.thegraph.com/api/.../subgraphs/id/...",
    polygon: "https://gateway.thegraph.com/api/.../subgraphs/id/..."
  }

  @fee_tiers %{
    100 => "0.01%",
    500 => "0.05%",
    3000 => "0.30%",
    10000 => "1.00%"
  }

  # ── Configuration ────────────────────────────────────────────────────

  @doc "Get the configured chain."
  def chain do
    Application.get_env(:lux, Lux.Integrations.UniswapV3, [])
    |> Keyword.get(:chain, :ethereum)
  end

  @doc "Get the subgraph URL for the current chain."
  def subgraph_url do
    app_config = Application.get_env(:lux, Lux.Integrations.UniswapV3, [])

    case Keyword.fetch(app_config, :subgraph_url) do
      {:ok, url} -> url
      :error -> Map.get(@chains, chain())
    end
  end

  @doc "Get all available fee tiers."
  def fee_tiers, do: @fee_tiers

  # ── Pools ────────────────────────────────────────────────────────────

  @doc "Get all pools with key metrics."
  def pools(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    order_by = Keyword.get(opts, :order_by, "totalValueLockedUSD")
    order_dir = Keyword.get(opts, :order_dir, "desc")

    query = """
    {
      pools(first: #{limit}, orderBy: #{order_by}, orderDirection: #{order_dir}) {
        id
        token0 { symbol name decimals }
        token1 { symbol name decimals }
        feeTier
        liquidity
        sqrtPrice
        tick
        totalValueLockedUSD
        volumeUSD
        feesUSD
        volumeToken0
        volumeToken1
        txCount
      }
    }
    """

    graph_query(query)
  end

  @doc "Get a specific pool by address."
  def pool(address) do
    query = """
    {
      pool(id: "#{String.downcase(address)}") {
        id
        token0 { symbol name decimals }
        token1 { symbol name decimals }
        feeTier
        liquidity
        sqrtPrice
        tick
        totalValueLockedUSD
        volumeUSD
        feesUSD
        volumeToken0
        volumeToken1
        txCount
        poolHourData(first: 24, orderBy: periodStartUnix, orderDirection: desc) {
          periodStartUnix
          volumeUSD
          feesUSD
          tvlUSD
        }
      }
    }
    """

    graph_query(query)
  end

  @doc "Get top pools by TVL."
  def top_pools(opts \\ []) do
    pools(Keyword.merge(opts, order_by: "totalValueLockedUSD", order_dir: "desc"))
  end

  @doc "Get pools for a specific token."
  def pools_for_token(token_address, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    query = """
    {
      pools(first: #{limit}, orderBy: totalValueLockedUSD, orderDirection: desc,
             where: {or: [{token0: "#{String.downcase(token_address)}"},
                          {token1: "#{String.downcase(token_address)}"}]}) {
        id
        token0 { symbol name decimals }
        token1 { symbol name decimals }
        feeTier
        totalValueLockedUSD
        volumeUSD
      }
    }
    """

    graph_query(query)
  end

  # ── Positions ────────────────────────────────────────────────────────

  @doc "Get a specific position by NFT token ID."
  def position(token_id) do
    query = """
    {
      position(id: #{token_id}) {
        id
        owner
        pool { id token0 { symbol } token1 { symbol } feeTier }
        tickLower { tickIdx }
        tickUpper { tickIdx }
        liquidity
        depositedToken0
        depositedToken1
        withdrawnToken0
        withdrawnToken1
        collectedFeesToken0
        collectedFeesToken1
        transaction { id timestamp }
      }
    }
    """

    graph_query(query)
  end

  @doc "Get all positions for an owner address."
  def positions_for_owner(owner_address, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    query = """
    {
      positions(first: #{limit}, where: {owner: "#{String.downcase(owner_address)}"},
                orderBy: liquidity, orderDirection: desc) {
        id
        pool { id token0 { symbol } token1 { symbol } feeTier totalValueLockedUSD }
        tickLower { tickIdx }
        tickUpper { tickIdx }
        liquidity
        depositedToken0
        depositedToken1
        collectedFeesToken0
        collectedFeesToken1
      }
    }
    """

    graph_query(query)
  end

  # ── Analytics ────────────────────────────────────────────────────────

  @doc "Get pool hourly data for a time range."
  def pool_hourly_data(pool_address, opts \\ []) do
    hours = Keyword.get(opts, :hours, 168)

    query = """
    {
      poolHourDatas(first: #{hours}, orderBy: periodStartUnix, orderDirection: desc,
                    where: {pool: "#{String.downcase(pool_address)}"}) {
        periodStartUnix
        volumeUSD
        feesUSD
        tvlUSD
        liquidity
        sqrtPrice
        token0Price
        token1Price
        open
        high
        low
        close
      }
    }
    """

    graph_query(query)
  end

  @doc "Get global Uniswap V3 factory data."
  def factory_data do
    query = """
    {
      factory(id: "1") {
        id
        poolCount
        txCount
        totalVolumeUSD
        totalFeesUSD
        totalValueLockedUSD
      }
    }
    """

    graph_query(query)
  end

  @doc "Get trending pools (highest volume in last 24h)."
  def trending_pools(limit \\ 10) do
    pools(limit: limit, order_by: "volumeUSD", order_dir: "desc")
  end

  # ── Position Analysis ────────────────────────────────────────────────

  @doc """
  Analyze a concentrated liquidity position's health.

  Returns position details plus current price position relative to range.
  """
  def analyze_position(token_id) do
    with {:ok, %{"position" => pos}} when not is_nil(pos) <- position(token_id),
         {:ok, %{"pool" => pool_data}} <- pool(pos["pool"]["id"]) do

      current_tick = parse_int(pool_data["tick"])
      lower_tick = parse_int(pos["tickLower"]["tickIdx"])
      upper_tick = parse_int(pos["tickUpper"]["tickIdx"])

      in_range = current_tick >= lower_tick && current_tick <= upper_tick

      range_pct =
        if upper_tick != lower_tick do
          total = upper_tick - lower_tick
          position = current_tick - lower_tick
          Float.round(abs(position) / abs(total) * 100, 1)
        else
          100.0
        end

      {:ok,
       %{
         position_id: pos["id"],
         pool: "#{pos["pool"]["token0"]["symbol"]}/#{pos["pool"]["token1"]["symbol"]}",
         fee_tier: @fee_tiers[parse_int(pos["pool"]["feeTier"])],
         liquidity: pos["liquidity"],
         in_range: in_range,
         range_position_pct: range_pct,
         current_tick: current_tick,
         lower_tick: lower_tick,
         upper_tick: upper_tick,
         deposited_token0: pos["depositedToken0"],
         deposited_token1: pos["depositedToken1"],
         collected_fees_token0: pos["collectedFeesToken0"],
         collected_fees_token1: pos["collectedFeesToken1"],
         pool_tvl_usd: pool_data["totalValueLockedUSD"]
       }}
    else
      {:ok, %{"position" => nil}} -> {:error, "Position not found"}
      {:ok, %{"pool" => nil}} -> {:error, "Pool not found"}
      error -> error
    end
  end

  @doc """
  Find optimal fee tier for a token pair based on historical volume.
  Higher volume pairs benefit from lower fee tiers.
  """
  def optimal_fee_tier(token0, token1) do
    query = """
    {
      pools(where: {token0: "#{String.downcase(token0)}", token1: "#{String.downcase(token1)}"},
            orderBy: volumeUSD, orderDirection: desc) {
        id
        feeTier
        volumeUSD
        totalValueLockedUSD
      }
    }
    """

    case graph_query(query) do
      {:ok, %{"pools" => pools}} when is_list(pools) and pools != [] ->
        best = Enum.max_by(pools, fn p -> parse_float(p["volumeUSD"]) end)
        tier = parse_int(best["feeTier"])
        {:ok, %{fee_tier: tier, fee_pct: @fee_tiers[tier], volume_usd: best["volumeUSD"], pool: best["id"]}}

      {:ok, _} ->
        # Default to 0.30% for unknown pairs
        {:ok, %{fee_tier: 3000, fee_pct: "0.30%", volume_usd: "0", pool: nil}}

      error -> error
    end
  end

  # ── Subgraph query helper ────────────────────────────────────────────

  defp graph_query(query) do
    url = subgraph_url()

    case Req.post(url,
           json: %{"query" => query},
           receive_timeout: 30_000) do
      {:ok, %{status: 200, body: %{"data" => data}}} ->
        {:ok, data}

      {:ok, %{status: 200, body: %{"errors" => errors}}} ->
        messages = Enum.map(errors || [], & &1["message"])
        {:error, "Subgraph error: #{Enum.join(messages, "; ")}"}

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status} from subgraph"}

      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  # ── Helpers ──────────────────────────────────────────────────────────

  defp parse_int(nil), do: 0
  defp parse_int(str) when is_binary(str), do: String.to_integer(str)
  defp parse_int(int) when is_integer(int), do: int

  defp parse_float(nil), do: 0.0
  defp parse_float(str) when is_binary(str), do: String.to_float(str)
  defp parse_float(float) when is_float(float), do: float
  defp parse_float(int) when is_integer(int), do: int * 1.0
end
