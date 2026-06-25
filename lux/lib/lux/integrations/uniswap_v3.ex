defmodule Lux.Integrations.UniswapV3 do
  @moduledoc """
  Lux integration for Uniswap V3 concentrated liquidity.

  Provides contract addresses, fee-tier selection, price-range helpers,
  and configuration accessors for RPC / subgraph connectivity.

  ## Configuration

      config :lux, Lux.Integrations.UniswapV3,
        rpc_url:       System.get_env("ETH_RPC_URL"),
        subgraph_url:  System.get_env("UNISWAP_SUBGRAPH_URL"),
        chain_id:      System.get_env("CHAIN_ID") || "1"

  ## Mainnet contract addresses

  | Contract                      | Address                                    |
  |-------------------------------|--------------------------------------------|
  | Factory                       | 0x1F98431c8aD98523631AE4a59f267346ea31F984 |
  | NonfungiblePositionManager    | 0xC36442b4a4522E871399CD717aBDD847Ab11FE88 |
  | SwapRouter                    | 0xE592427A0AEce92De3Edee1F18E0157C05861564 |
  | QuoterV2                      | 0x61fFE014bA17989E743c5F6cB21bF9697530B21e |

  ## Fee tiers

  | Tier     | bps  | Suited for          |
  |----------|------|---------------------|
  | :lowest  |  100 | Stablecoin pairs    |
  | :low     |  500 | Stable-major pairs  |
  | :medium  | 3000 | Major-major pairs   |
  | :high    |10000 | Exotic / long-tail  |
  """

  @factory          "0x1F98431c8aD98523631AE4a59f267346ea31F984"
  @position_manager "0xC36442b4a4522E871399CD717aBDD847Ab11FE88"
  @swap_router      "0xE592427A0AEce92De3Edee1F18E0157C05861564"
  @quoter_v2        "0x61fFE014bA17989E743c5F6cB21bF9697530B21e"

  @fee_tiers %{lowest: 100, low: 500, medium: 3_000, high: 10_000}

  def factory,          do: @factory
  def position_manager, do: @position_manager
  def swap_router,      do: @swap_router
  def quoter_v2,        do: @quoter_v2
  def fee_tiers,        do: @fee_tiers

  @doc "Ethereum JSON-RPC endpoint URL."
  def rpc_url do
    Application.get_env(:lux, __MODULE__, [])[:rpc_url] ||
      System.get_env("ETH_RPC_URL") ||
      raise ArgumentError, "ETH_RPC_URL not configured for #{__MODULE__}"
  end

  @doc "Uniswap V3 subgraph URL."
  def subgraph_url do
    Application.get_env(:lux, __MODULE__, [])[:subgraph_url] ||
      System.get_env("UNISWAP_SUBGRAPH_URL") ||
      "https://api.thegraph.com/subgraphs/name/uniswap/uniswap-v3"
  end

  @doc "Chain ID string (default: \"1\" = Ethereum mainnet)."
  def chain_id do
    Application.get_env(:lux, __MODULE__, [])[:chain_id] ||
      System.get_env("CHAIN_ID") ||
      "1"
  end

  @doc "Base JSON headers for RPC calls."
  def headers do
    [{"Accept", "application/json"}, {"Content-Type", "application/json"}]
  end

  @doc "Headers for subgraph GraphQL calls (adds Bearer token when GRAPH_API_KEY is set)."
  def subgraph_headers do
    base = [{"Accept", "application/json"}, {"Content-Type", "application/json"}]
    case System.get_env("GRAPH_API_KEY") do
      nil -> base
      key -> [{"Authorization", "Bearer #{key}"} | base]
    end
  end

  @doc """
  Picks the optimal fee tier for a token pair.

  Heuristic:
  - stable/stable  → :lowest (0.01%)
  - stable/major   → :low    (0.05%)
  - major/major    → :medium (0.30%)
  - everything else → :high  (1.00%)
  """
  @spec select_fee_tier(String.t(), String.t()) :: :lowest | :low | :medium | :high
  def select_fee_tier(token0, token1) do
    stables = MapSet.new(~w[USDC USDT DAI FRAX LUSD crvUSD])
    majors  = MapSet.new(~w[WETH ETH WBTC BTC])
    t0 = String.upcase(token0)
    t1 = String.upcase(token1)
    cond do
      MapSet.member?(stables, t0) and MapSet.member?(stables, t1) -> :lowest
      MapSet.member?(stables, t0) or  MapSet.member?(stables, t1) -> :low
      MapSet.member?(majors,  t0) and MapSet.member?(majors,  t1) -> :medium
      true -> :high
    end
  end

  @doc """
  Returns a symmetric price range `{lower, upper}` centred on `current_price`.

  `range_factor` defaults to 0.10 (±10%).  Increase for wider, more passive
  ranges; decrease for tighter, higher-fee-capture ranges.
  """
  @spec compute_price_range(number(), float()) :: {float(), float()}
  def compute_price_range(current_price, range_factor \\ 0.10)
      when is_number(current_price) and is_float(range_factor) do
    lower = current_price * (1.0 - range_factor)
    upper = current_price * (1.0 + range_factor)
    {lower, upper}
  end
end
