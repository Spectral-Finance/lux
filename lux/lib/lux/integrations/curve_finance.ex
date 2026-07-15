defmodule Lux.Integrations.CurveFinance do
  @moduledoc """
  Read-only Curve Finance pool and gauge analytics.

  Fetches data from a configured GraphQL adapter and provides pure estimation
  helpers. It does not submit transactions, manage positions, stake gauges,
  claim CRV, or execute rebalances.

  ## Configuration

      config :lux, Lux.Integrations.CurveFinance,
        subgraph_url: System.get_env("CURVE_SUBGRAPH_URL"),
        rpc_url: System.get_env("ETH_RPC_URL"),
        crv_token: "0xD533a949740bb3306d119CC777fa900bA034cd52",
        registry_address: "0x90E00ACe148ca3b23Ac1bC8C240C2a7Dd9c2d7f6"

  ## Usage

      alias Lux.Integrations.CurveFinance

      # Fetch pool data
      {:ok, pools} = CurveFinance.fetch_pools()

      # Estimate slippage for a trade
      slippage = CurveFinance.estimate_slippage(10_000, 500_000_000)

      # Select optimal pool for a token pair
      {:ok, pool} = CurveFinance.select_pool("USDC", "USDT", pools)

      # Calculate estimated CRV APY
      apy = CurveFinance.estimate_crv_apy(0.005, 0.6, 500_000_000)
  """

  @default_registry "0x90E00ACe148ca3b23Ac1bC8C240C2a7Dd9c2d7f6"
  @default_crv_token "0xD533a949740bb3306d119CC777fa900bA034cd52"
  @annual_crv_emission 200_000_000

  @typedoc "A Curve pool with its metadata"
  @type pool :: %{
          id: String.t(),
          address: String.t(),
          name: String.t(),
          coins: [map()],
          tvl_usd: float(),
          volume_usd: float(),
          fee: float(),
          type: String.t() | nil
        }

  @typedoc "A gauge with staking info"
  @type gauge :: %{
          id: String.t(),
          pool_id: String.t(),
          working_supply: String.t(),
          supply: String.t(),
          vote_amount: String.t()
        }

  @doc "Returns the subgraph URL for querying pool data."
  @spec subgraph_url() :: String.t()
  def subgraph_url do
    Application.get_env(:lux, __MODULE__, [])[:subgraph_url] ||
      System.get_env("CURVE_SUBGRAPH_URL") ||
      raise ArgumentError,
            "Curve subgraph is not configured; set :subgraph_url or CURVE_SUBGRAPH_URL"
  end

  @doc "Returns the Ethereum RPC URL."
  @spec rpc_url() :: String.t()
  def rpc_url do
    Application.get_env(:lux, __MODULE__, [])[:rpc_url] ||
      System.get_env("ETH_RPC_URL") ||
      raise ArgumentError, "ETH_RPC_URL not configured"
  end

  @doc "Returns the Curve registry contract address."
  @spec registry_address() :: String.t()
  def registry_address do
    Application.get_env(:lux, __MODULE__, [])[:registry_address] || @default_registry
  end

  @doc "Returns the CRV token address."
  @spec crv_token() :: String.t()
  def crv_token do
    Application.get_env(:lux, __MODULE__, [])[:crv_token] || @default_crv_token
  end

  @doc "Returns HTTP headers for API requests."
  @spec headers() :: list({String.t(), String.t()})
  def headers do
    [{"Accept", "application/json"}, {"Content-Type", "application/json"}]
  end

  @doc """
  Fetches all Curve pools from the subgraph.

  Returns `{:ok, [pool()]}` on success or `{:error, reason}` on failure.
  """
  @spec fetch_pools() :: {:ok, [pool()]} | {:error, term()}
  def fetch_pools do
    query = """
    {
      pools(first: 100, orderBy: totalValueLockedUSD, orderDirection: desc) {
        id
        address
        name
        type
        fee
        totalValueLockedUSD
        volumeUSD
        coins {
          address
          symbol
          decimals
        }
      }
    }
    """

    case Req.post(
           subgraph_url(),
           request_options(json: %{query: query}, headers: headers(), receive_timeout: 30_000)
         ) do
      {:ok, %{status: 200, body: %{"data" => %{"pools" => pools}}}} ->
        parsed = Enum.map(pools, &parse_pool/1)
        {:ok, parsed}

      {:ok, %{status: 200, body: %{"errors" => errors}}} ->
        {:error, {:graphql_errors, errors}}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Fetches gauge data for a specific pool.

  Returns `{:ok, [gauge()]}` on success.
  """
  @spec fetch_gauges(pool_id :: String.t()) :: {:ok, [gauge()]} | {:error, term()}
  def fetch_gauges(pool_id) do
    query = """
    {
      gauges(where: {pool: "#{pool_id}"}) {
        id
        pool {
          id
        }
        workingSupply
        supply
        voteAmount
      }
    }
    """

    case Req.post(
           subgraph_url(),
           request_options(json: %{query: query}, headers: headers(), receive_timeout: 30_000)
         ) do
      {:ok, %{status: 200, body: %{"data" => %{"gauges" => gauges}}}} ->
        parsed = Enum.map(gauges, &parse_gauge/1)
        {:ok, parsed}

      {:ok, %{status: 200, body: %{"errors" => errors}}} ->
        {:error, {:graphql_errors, errors}}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Estimates slippage for a trade given trade size and pool TVL.

  Uses a simplified bonding curve approximation, capped at 5%.

  ## Examples

      iex> CurveFinance.estimate_slippage(10_000, 500_000_000)
      0.00002
  """
  @spec estimate_slippage(trade_size_usd :: float(), pool_tvl_usd :: float()) :: float()
  def estimate_slippage(trade_size_usd, pool_tvl_usd)
      when is_number(pool_tvl_usd) and pool_tvl_usd > 0 do
    ratio = trade_size_usd / pool_tvl_usd
    min(ratio * 0.001, 0.05)
  end

  def estimate_slippage(_, _), do: 0.05

  @doc """
  Selects the optimal Curve pool for a given stablecoin pair.

  Chooses the pool with the highest TVL among matching pairs.

  ## Examples

      iex> CurveFinance.select_pool("USDC", "USDT", pools)
      {:ok, %CurveFinance.Pool{...}}

      iex> CurveFinance.select_pool("NONEXIST", "TOKEN", [])
      {:error, :no_pool}
  """
  @spec select_pool(token_a :: String.t(), token_b :: String.t(), [pool()]) ::
          {:ok, pool()} | {:error, :no_pool}
  def select_pool(token_a, token_b, pools) when is_list(pools) do
    sym_a = String.upcase(token_a)
    sym_b = String.upcase(token_b)

    matching =
      Enum.filter(pools, fn pool ->
        syms = Enum.map(pool.coins, &String.upcase(&1.symbol || ""))
        sym_a in syms and sym_b in syms
      end)

    case Enum.max_by(matching, &Map.get(&1, :tvl_usd, 0.0), fn -> nil end) do
      nil -> {:error, :no_pool}
      pool -> {:ok, pool}
    end
  end

  def select_pool(_, _, _), do: {:error, :no_pool}

  @doc """
  Calculates estimated CRV APY based on gauge weight, CRV price, and pool TVL.

  Assumes ~200M CRV emitted annually distributed across gauges.

  ## Examples

      iex> CurveFinance.estimate_crv_apy(0.005, 0.6, 500_000_000)
      0.0000012
  """
  @spec estimate_crv_apy(
          gauge_weight :: float(),
          crv_price_usd :: float(),
          pool_tvl_usd :: float()
        ) :: float()
  def estimate_crv_apy(gauge_weight, crv_price_usd, pool_tvl_usd)
      when is_number(pool_tvl_usd) and pool_tvl_usd > 0
      when is_number(gauge_weight) and gauge_weight >= 0
      when is_number(crv_price_usd) and crv_price_usd >= 0 do
    annual_crv = @annual_crv_emission * gauge_weight
    annual_usd = annual_crv * crv_price_usd
    annual_usd / pool_tvl_usd
  end

  def estimate_crv_apy(_, _, _), do: 0.0

  @doc """
  Calculates the optimal rebalance threshold based on pool fee and slippage.

  Returns the minimum price deviation percentage that justifies a rebalance.
  """
  @spec rebalance_threshold(pool_fee :: float(), avg_slippage :: float()) :: float()
  def rebalance_threshold(pool_fee, avg_slippage) do
    max(pool_fee * 1.5, avg_slippage * 2)
  end

  @doc """
  Computes a read-only rebalancing recommendation.

  Returns `:rebalance` if the drift exceeds the threshold, `:hold` otherwise.
  """
  @spec should_rebalance(
          current_allocation :: float(),
          target_allocation :: float(),
          threshold :: float()
        ) ::
          :rebalance | :hold
  def should_rebalance(current, target, threshold) do
    drift = abs(current - target)
    if drift > threshold, do: :rebalance, else: :hold
  end

  @doc """
  Fetches current CRV price from CoinGecko API.

  Returns `{:ok, float()}` with price in USD or `{:error, reason}`.
  """
  @spec fetch_crv_price() :: {:ok, float()} | {:error, term()}
  def fetch_crv_price do
    endpoint =
      Application.get_env(:lux, __MODULE__, [])[:price_url] ||
        "https://api.coingecko.com/api/v3/simple/price"

    case Req.get(
           endpoint,
           request_options(
             query: %{ids: "curve-dao-token", vs_currencies: "usd"},
             receive_timeout: 15_000
           )
         ) do
      {:ok, %{status: 200, body: %{"curve-dao-token" => %{"usd" => price}}}} ->
        {:ok, price / 1.0}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Fetches pool TVL data from the subgraph.

  Returns a map of pool IDs to their TVL in USD.
  """
  @spec fetch_pool_tvls([pool()]) :: %{String.t() => float()}
  def fetch_pool_tvls(pools) do
    Enum.into(pools, %{}, fn pool ->
      {pool.id, pool.tvl_usd}
    end)
  end

  # ---- Internal helpers ----

  defp request_options(options) do
    Keyword.merge(options, Application.get_env(:lux, __MODULE__, [])[:req_options] || [])
  end

  defp parse_pool(%{"coins" => coins} = data) do
    %{
      id: data["id"],
      address: data["address"] || "",
      name: data["name"] || "",
      type: data["type"],
      fee: parse_float(data["fee"]),
      tvl_usd: parse_float(data["totalValueLockedUSD"]),
      volume_usd: parse_float(data["volumeUSD"]),
      coins:
        Enum.map(coins, fn c ->
          %{
            address: c["address"] || "",
            symbol: c["symbol"] || "",
            decimals: String.to_integer(c["decimals"] || "18")
          }
        end)
    }
  end

  defp parse_gauge(%{"pool" => %{"id" => pool_id}} = data) do
    %{
      id: data["id"],
      pool_id: pool_id,
      working_supply: data["workingSupply"] || "0",
      supply: data["supply"] || "0",
      vote_amount: data["voteAmount"] || "0"
    }
  end

  defp parse_float(s) when is_binary(s) do
    case Float.parse(s) do
      {n, _} -> n
      :error -> 0.0
    end
  end

  defp parse_float(n) when is_number(n), do: n / 1.0
  defp parse_float(_), do: 0.0
end
