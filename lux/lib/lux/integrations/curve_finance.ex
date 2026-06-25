defmodule Lux.Integrations.CurveFinance do
  @moduledoc """
  Curve Finance Integration for stablecoin management ($900).

  Provides configuration, pool analysis helpers, and gauge
  reward calculators for Curve Finance pools.

  ## Configuration

      config :lux, Lux.Integrations.CurveFinance,
        subgraph_url: System.get_env("CURVE_SUBGRAPH_URL"),
        rpc_url: System.get_env("ETH_RPC_URL")
  """

  @default_subgraph "https://api.thegraph.com/subgraphs/name/messari/curve-finance-ethereum"
  @registry_address "0x90E00ACe148ca3b23Ac1bC8C240C2a7Dd9c2d7f6"
  @crv_token "0xD533a949740bb3306d119CC777fa900bA034cd52"

  def subgraph_url do
    Application.get_env(:lux, __MODULE__, [])[:subgraph_url] ||
      System.get_env("CURVE_SUBGRAPH_URL") || @default_subgraph
  end

  def rpc_url do
    Application.get_env(:lux, __MODULE__, [])[:rpc_url] ||
      System.get_env("ETH_RPC_URL") ||
      raise ArgumentError, "ETH_RPC_URL not configured"
  end

  def registry_address, do: @registry_address
  def crv_token, do: @crv_token

  def headers do
    [{"Accept", "application/json"}, {"Content-Type", "application/json"}]
  end

  @doc "Calculates slippage for a given trade size vs pool TVL."
  @spec estimate_slippage(float(), float()) :: float()
  def estimate_slippage(trade_size_usd, pool_tvl_usd) when pool_tvl_usd > 0 do
    # Simplified bonding curve approximation for stable pools
    ratio = trade_size_usd / pool_tvl_usd
    min(ratio * 0.001, 0.05)  # capped at 5%
  end
  def estimate_slippage(_, _), do: 0.05

  @doc "Selects the optimal Curve pool for a stablecoin pair."
  @spec select_pool(String.t(), String.t(), list()) :: {:ok, map()} | {:error, :no_pool}
  def select_pool(token_a, token_b, pools) do
    matching = Enum.filter(pools, fn pool ->
      coins = Map.get(pool, "coins", [])
      syms  = Enum.map(coins, &String.upcase(&1["symbol"] || ""))
      String.upcase(token_a) in syms and String.upcase(token_b) in syms
    end)

    case Enum.max_by(matching, &(Map.get(&1, "tvlUSD", 0) |> parse_float()), fn -> nil end) do
      nil  -> {:error, :no_pool}
      pool -> {:ok, pool}
    end
  end

  @doc "Calculates estimated CRV APY given gauge weight and emission rate."
  @spec estimate_crv_apy(float(), float(), float()) :: float()
  def estimate_crv_apy(gauge_weight, crv_price_usd, pool_tvl_usd) when pool_tvl_usd > 0 do
    # ~200M CRV emitted per year, gauge_weight is fraction of total
    annual_crv = 200_000_000 * gauge_weight
    annual_usd = annual_crv * crv_price_usd
    annual_usd / pool_tvl_usd
  end
  def estimate_crv_apy(_, _, _), do: 0.0

  defp parse_float(s) when is_binary(s), do: elem(Float.parse(s), 0)
  defp parse_float(n) when is_number(n), do: n / 1
  defp parse_float(_), do: 0.0
end
