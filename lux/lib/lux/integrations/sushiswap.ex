defmodule Lux.Integrations.SushiSwap do
  @moduledoc """
  SushiSwap Integration and Cross-Chain Bridge Support ($750).

  Provides configuration helpers for SushiSwap V3 pools,
  cross-chain routing via LayerZero/Stargate bridge, and SUSHI farming.

  ## Configuration

      config :lux, Lux.Integrations.SushiSwap,
        rpc_url: System.get_env("ETH_RPC_URL"),
        chain_id: "1"
  """

  # SushiSwap V3 mainnet contracts
  @factory  "0xbACEB8eC6b9355Dfc0269C18bac9d6E2Bdc29C4F"
  @router   "0x827179dD56d07A7eeA32e3873493835da2866976"
  @sushi    "0x6B3595068778DD592e39A122f4f5a5cF09C90fE2"

  # Sushi subgraph (V3)
  @default_subgraph "https://api.thegraph.com/subgraphs/name/sushi-v3/v3-ethereum"

  # Supported chains for cross-chain routing
  @supported_chains ~w[ethereum arbitrum optimism polygon bnb avalanche base]

  def factory, do: @factory
  def router,  do: @router
  def sushi,   do: @sushi
  def supported_chains, do: @supported_chains

  def subgraph_url do
    Application.get_env(:lux, __MODULE__, [])[:subgraph_url] || @default_subgraph
  end

  def rpc_url do
    Application.get_env(:lux, __MODULE__, [])[:rpc_url] ||
      System.get_env("ETH_RPC_URL") ||
      raise ArgumentError, "ETH_RPC_URL not configured"
  end

  def headers, do: [{"Accept", "application/json"}, {"Content-Type", "application/json"}]
  def fee_tiers, do: %{lowest: 100, low: 500, medium: 3_000, high: 10_000}

  @doc "Returns true if cross-chain routing is supported between two chains."
  @spec cross_chain_supported?(String.t(), String.t()) :: boolean()
  def cross_chain_supported?(chain_a, chain_b) do
    String.downcase(chain_a) in @supported_chains and
      String.downcase(chain_b) in @supported_chains and
      chain_a != chain_b
  end

  @doc "Calculates SUSHI APR from emission rate and pool TVL."
  @spec estimate_sushi_apr(float(), float(), float()) :: float()
  def estimate_sushi_apr(sushi_per_block, sushi_price_usd, pool_tvl_usd)
      when pool_tvl_usd > 0 do
    # ~6500 blocks/day on mainnet
    annual_sushi = sushi_per_block * 6_500 * 365
    annual_usd   = annual_sushi * sushi_price_usd
    annual_usd / pool_tvl_usd
  end
  def estimate_sushi_apr(_, _, _), do: 0.0
end
