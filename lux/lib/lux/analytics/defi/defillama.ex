defmodule Lux.Analytics.Defi.DefiLlama do
  @moduledoc """
  DeFiLlama REST API connector for protocol TVL, DEX volumes, yield pools, and stablecoins.
  """

  @base_url "https://api.llama.fi"
  @yields_url "https://yields.llama.fi"

  @doc """
  Builds request URL for protocol TVL details.
  """
  @spec protocol_tvl_url(String.t()) :: String.t()
  def protocol_tvl_url(protocol_slug) do
    "#{@base_url}/protocol/#{String.downcase(protocol_slug)}"
  end

  @doc """
  Builds request URL for multi-chain TVL overview.
  """
  @spec chains_tvl_url() :: String.t()
  def chains_tvl_url, do: "#{@base_url}/v2/chains"

  @doc """
  Builds request URL for DEX volumes overview.
  """
  @spec dex_volume_url(String.t() | nil) :: String.t()
  def dex_volume_url(chain \\ nil) do
    if chain,
      do: "#{@base_url}/overview/dexs/#{String.downcase(chain)}",
      else: "#{@base_url}/overview/dexs"
  end

  @doc """
  Builds request URL for yield pools list.
  """
  @spec yield_pools_url() :: String.t()
  def yield_pools_url, do: "#{@yields_url}/pools"

  @doc """
  Parses raw protocol TVL payload and calculates 24h change and chain distribution.
  """
  @spec parse_protocol_tvl(map()) :: %{
          name: String.t(),
          symbol: String.t(),
          category: String.t(),
          total_tvl_usd: float(),
          change_1d_pct: float(),
          chain_tvls: map()
        }
  def parse_protocol_tvl(data) when is_map(data) do
    name = data["name"] || "Unknown"
    symbol = data["symbol"] || ""
    category = data["category"] || "DeFi"

    # Total TVL from current chainTvls or tvl array
    chain_tvls = data["currentChainTvls"] || %{}
    total_tvl = parse_float(data["tvl"] || Enum.sum(Map.values(chain_tvls)))

    change_1d = parse_float(data["change_1d"])

    %{
      name: name,
      symbol: symbol,
      category: category,
      total_tvl_usd: Float.round(total_tvl, 2),
      change_1d_pct: Float.round(change_1d, 2),
      chain_tvls: chain_tvls
    }
  end

  @doc """
  Filters yield pools by criteria (minimum TVL, chain, APY thresholds).
  """
  @spec filter_yield_pools(list(map()), map()) :: list(map())
  def filter_yield_pools(pools, criteria \\ %{}) when is_list(pools) do
    min_tvl = parse_float(criteria[:min_tvl_usd] || criteria["min_tvl_usd"] || 0.0)
    target_chain = criteria[:chain] || criteria["chain"]
    min_apy = parse_float(criteria[:min_apy_pct] || criteria["min_apy_pct"] || 0.0)
    max_apy = parse_float(criteria[:max_apy_pct] || criteria["max_apy_pct"] || 1000.0)

    pools
    |> Enum.map(fn p ->
      %{
        pool_id: p["pool"] || p[:pool_id],
        project: p["project"] || p[:project],
        symbol: p["symbol"] || p[:symbol],
        chain: p["chain"] || p[:chain],
        tvl_usd: parse_float(p["tvlUsd"] || p[:tvl_usd]),
        apy_pct: parse_float(p["apy"] || p[:apy_pct]),
        apy_base_pct: parse_float(p["apyBase"] || p[:apy_base_pct]),
        apy_reward_pct: parse_float(p["apyReward"] || p[:apy_reward_pct])
      }
    end)
    |> Enum.filter(fn p ->
      p.tvl_usd >= min_tvl and
        p.apy_pct >= min_apy and
        p.apy_pct <= max_apy and
        (is_nil(target_chain) or String.downcase(p.chain) == String.downcase(target_chain))
    end)
  end

  defp parse_float(val) when is_float(val), do: val
  defp parse_float(val) when is_integer(val), do: val * 1.0
  defp parse_float(val) when is_binary(val) do
    case Float.parse(val) do
      {num, _} -> num
      :error -> 0.0
    end
  end
  defp parse_float(_), do: 0.0
end
