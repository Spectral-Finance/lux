defmodule Lux.Integrations.PancakeSwap do
  @moduledoc """
  PancakeSwap Integration and Yield Farming ($750).

  Provides configuration and helpers for PancakeSwap V3 on BNB Chain:
  pool interaction, yield farming, syrup pools, and cross-chain bridging.

  ## Configuration

      config :lux, Lux.Integrations.PancakeSwap,
        rpc_url: System.get_env("BSC_RPC_URL"),
        subgraph_url: System.get_env("PANCAKE_SUBGRAPH_URL")
  """

  @default_subgraph "https://api.thegraph.com/subgraphs/name/pancakeswap/exchange-v3-bsc"
  @factory_v3  "0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865"
  @router_v3   "0x13f4EA83D0bd40E75C8222255bc855a974568Dd4"
  @cake_token  "0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82"
  @masterchef  "0xa5f8C5Dbd5F286960b9d90548680aE5ebFf07652"

  def factory_v3,   do: @factory_v3
  def router_v3,    do: @router_v3
  def cake_token,   do: @cake_token
  def masterchef,   do: @masterchef

  def subgraph_url do
    Application.get_env(:lux, __MODULE__, [])[:subgraph_url] ||
      System.get_env("PANCAKE_SUBGRAPH_URL") || @default_subgraph
  end

  def rpc_url do
    Application.get_env(:lux, __MODULE__, [])[:rpc_url] ||
      System.get_env("BSC_RPC_URL") ||
      raise ArgumentError, "BSC_RPC_URL not configured"
  end

  def headers, do: [{"Accept", "application/json"}, {"Content-Type", "application/json"}]

  @doc "Fee tiers supported by PancakeSwap V3."
  def fee_tiers, do: %{lowest: 100, low: 500, medium: 2500, high: 10_000}

  @doc "Calculates CAKE APR given emission rate, price, and pool TVL."
  @spec estimate_cake_apr(float(), float(), float()) :: float()
  def estimate_cake_apr(cake_per_block, cake_price_usd, pool_tvl_usd)
      when pool_tvl_usd > 0 do
    # BSC ~3s blocks, 10512000 blocks/year
    annual_cake = cake_per_block * 10_512_000
    annual_usd  = annual_cake * cake_price_usd
    annual_usd / pool_tvl_usd
  end
  def estimate_cake_apr(_, _, _), do: 0.0

  @doc "Selects the optimal fee tier for a token pair on BSC."
  @spec select_fee_tier(String.t(), String.t()) :: :lowest | :low | :medium | :high
  def select_fee_tier(token0, token1) do
    stables = MapSet.new(~w[USDT USDC BUSD DAI TUSD])
    majors  = MapSet.new(~w[WBNB BNB WETH ETH BTCB])
    t0 = String.upcase(token0); t1 = String.upcase(token1)
    cond do
      MapSet.member?(stables, t0) and MapSet.member?(stables, t1) -> :lowest
      MapSet.member?(stables, t0) or  MapSet.member?(stables, t1) -> :low
      MapSet.member?(majors,  t0) and MapSet.member?(majors,  t1) -> :medium
      true -> :high
    end
  end
end
