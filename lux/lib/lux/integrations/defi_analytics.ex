defmodule Lux.Integrations.DeFiAnalytics do
  @moduledoc """
  DeFi Analytics Integration with DeFiLlama and Dune ($750).

  Provides TVL tracking, protocol metrics, yield analytics,
  and volume analysis via DeFiLlama public API and Dune Analytics.

  ## Configuration

      config :lux, Lux.Integrations.DeFiAnalytics,
        dune_api_key: System.get_env("DUNE_API_KEY")
  """

  @defillama_base "https://api.llama.fi"
  @dune_base "https://api.dune.com/api/v1"

  def defillama_url, do: @defillama_base
  def dune_url, do: @dune_base

  def defillama_headers do
    [{"Accept", "application/json"}, {"Content-Type", "application/json"}]
  end

  def dune_headers do
    api_key = Application.get_env(:lux, __MODULE__, [])[:dune_api_key] ||
              System.get_env("DUNE_API_KEY") || ""
    [{"X-Dune-API-Key", api_key}, {"Accept", "application/json"}]
  end

  # DeFiLlama endpoints
  def tvl_url(protocol),       do: @defillama_base <> "/tvl/#{protocol}"
  def protocols_url,           do: @defillama_base <> "/protocols"
  def protocol_url(slug),      do: @defillama_base <> "/protocol/#{slug}"
  def yields_url,              do: "https://yields.llama.fi/pools"
  def chains_tvl_url,          do: @defillama_base <> "/v2/chains"
  def historical_tvl_url(slug), do: @defillama_base <> "/protocol/#{slug}"

  # Dune endpoints
  def dune_query_url(query_id), do: @dune_base <> "/query/#{query_id}/execute"
  def dune_result_url(exec_id), do: @dune_base <> "/execution/#{exec_id}/results"

  @doc "Filters yield pools by minimum APY and chain."
  @spec filter_pools(list(), keyword()) :: list()
  def filter_pools(pools, opts \\ []) do
    min_apy  = Keyword.get(opts, :min_apy, 0.0)
    chain    = Keyword.get(opts, :chain)
    min_tvl  = Keyword.get(opts, :min_tvl_usd, 0)

    pools
    |> Enum.filter(fn p ->
      apy = p["apy"] || 0
      tvl = p["tvlUsd"] || 0
      apy >= min_apy and tvl >= min_tvl and
        (is_nil(chain) or String.downcase(p["chain"] || "") == String.downcase(to_string(chain)))
    end)
    |> Enum.sort_by(&(&1["apy"] || 0), :desc)
  end

  @doc "Calculates 30-day average TVL from historical data points."
  @spec avg_tvl_30d(list()) :: float()
  def avg_tvl_30d(data_points) when length(data_points) > 0 do
    recent = Enum.take(data_points, -30)
    total  = Enum.sum(Enum.map(recent, &(&1["totalLiquidityUSD"] || &1["tvl"] || 0)))
    total / length(recent)
  end
  def avg_tvl_30d(_), do: 0.0
end
