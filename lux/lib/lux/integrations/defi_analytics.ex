defmodule Lux.Integrations.DefiAnalytics do
  @moduledoc """
  Integration with DeFiLlama and Dune Analytics for comprehensive DeFi protocol analysis.

  Provides TVL tracking, protocol metrics, yield analytics, volume analysis, and custom
  query support across both platforms.

  ## Configuration

      config :lux, Lux.Integrations.DefiAnalytics,
        defillama_base_url: "https://api.llama.fi",
        dune_base_url: "https://api.dune.com/api/v1",
        dune_api_key: System.get_env("DUNE_API_KEY")

  ## Features

  - **TVL Data**: Historical and current TVL for any protocol or chain
  - **Protocol Metrics**: Fees, revenue, volume, and user activity
  - **Yield Analytics**: Pool yields, APY comparisons, and farming opportunities
  - **Volume Analysis**: Trading volume across DEXes and chains
  - **Custom Queries**: Execute Dune Analytics SQL queries
  - **Historical Data**: Time-series data for trend analysis
  - **Alerts**: Monitor TVL or volume changes beyond thresholds

  ## Usage

      alias Lux.Integrations.DefiAnalytics

      # Get TVL for a protocol
      DefiAnalytics.protocol_tvl("aave")

      # Get yield pools on Ethereum
      DefiAnalytics.yield_pools("ethereum")

      # Get DEX volume data
      DefiAnalytics.dex_volume("uniswap")

      # Execute a Dune query
      DefiAnalytics.dune_query(12345)
  """

  @base_url "https://api.llama.fi"
  @dune_base_url "https://api.dune.com/api/v1"

  # ── Configuration ────────────────────────────────────────────────────

  @doc "Get the DeFiLlama base URL from config or default."
  def defillama_base_url do
    Application.get_env(:lux, Lux.Integrations.DefiAnalytics, [])
    |> Keyword.get(:defillama_base_url, @base_url)
  end

  @doc "Get the Dune Analytics base URL from config or default."
  def dune_base_url do
    Application.get_env(:lux, Lux.Integrations.DefiAnalytics, [])
    |> Keyword.get(:dune_base_url, @dune_base_url)
  end

  @doc "Get Dune API key from config."
  def dune_api_key do
    Application.get_env(:lux, Lux.Integrations.DefiAnalytics, [])
    |> Keyword.get(:dune_api_key, System.get_env("DUNE_API_KEY"))
  end

  @doc "Get standard HTTP headers for DeFiLlama."
  def defillama_headers do
    [
      {"Accept", "application/json"},
      {"Content-Type", "application/json"}
    ]
  end

  @doc "Get standard HTTP headers for Dune Analytics (includes API key)."
  def dune_headers do
    [
      {"Accept", "application/json"},
      {"Content-Type", "application/json"},
      {"x-dune-api-key", dune_api_key()}
    ]
  end

  # ── TVL Data ─────────────────────────────────────────────────────────

  @doc """
  Get current TVL data for all protocols.
  """
  def all_protocols_tvl do
    get("#{defillama_base_url()}/protocols")
  end

  @doc """
  Get TVL data for a specific protocol.
  """
  def protocol_tvl(protocol_slug) do
    get("#{defillama_base_url()}/protocol/#{protocol_slug}")
  end

  @doc """
  Get historical TVL for a protocol with optional time range.
  """
  def protocol_tvl_history(protocol_slug, days \\ 30) do
    get("#{defillama_base_url()}/protocol/#{protocol_slug}?days=#{days}")
  end

  @doc """
  Get TVL by chain across all protocols.
  """
  def chain_tvl(chain_name) do
    get("#{defillama_base_url()}/v2/historicalChainTvl/#{chain_name}")
  end

  @doc """
  Get current TVL for all chains.
  """
  def all_chains_tvl do
    get("#{defillama_base_url()}/chains")
  end

  # ── Protocol Metrics ─────────────────────────────────────────────────

  @doc """
  Get protocol metrics including fees, revenue, and volume.
  """
  def protocol_metrics(protocol_slug) do
    get("#{defillama_base_url()}/protocol/#{protocol_slug}")
  end

  @doc """
  Get recent fees for a protocol.
  """
  def protocol_fees(protocol_slug, days \\ 30) do
    get("#{defillama_base_url()}/fees/#{protocol_slug}?days=#{days}")
  end

  @doc """
  Get recent revenue for a protocol.
  """
  def protocol_revenue(protocol_slug, days \\ 30) do
    get("#{defillama_base_url()}/fees/#{protocol_slug}?days=#{days}")
  end

  # ── Yield Analytics ──────────────────────────────────────────────────

  @doc """
  Get all available yield pools.
  """
  def yield_pools(chain \\ nil) do
    url = "#{defillama_base_url()}/yields/pools"
    url = if chain, do: url <> "?chain=#{chain}", else: url
    get(url)
  end

  @doc """
  Get yield pool APY data over time.
  """
  def yield_pool_history(pool_id) do
    get("#{defillama_base_url()}/yields/chart/#{pool_id}")
  end

  @doc """
  Get top yield opportunities sorted by APY.
  """
  def top_yields(limit \\ 10, chain \\ nil) do
    url = "#{defillama_base_url()}/yields/pools?limit=#{limit}&sort=apy:desc"
    url = if chain, do: url <> "&chain=#{chain}", else: url
    get(url)
  end

  # ── Volume Analysis ──────────────────────────────────────────────────

  @doc """
  Get DEX volume data.
  """
  def dex_volume(dex_name \\ nil) do
    url = "#{defillama_base_url()}/dexs"
    url = if dex_name, do: url <> "?dex=#{dex_name}", else: url
    get(url)
  end

  @doc """
  Get DEX volume over time.
  """
  def dex_volume_history(dex_name, days \\ 30) do
    get("#{defillama_base_url()}/dexs/#{dex_name}?days=#{days}")
  end

  @doc """
  Get overall DEX volume aggregated by chain.
  """
  def dex_volume_by_chain do
    get("#{defillama_base_url()}/dexs/volume")
  end

  @doc """
  Get aggregated volume for a specific chain.
  """
  def chain_volume_history(chain, days \\ 30) do
    get("#{defillama_base_url()}/dexs/volume/#{chain}?days=#{days}")
  end

  # ── Dune Analytics ───────────────────────────────────────────────────

  @doc """
  Execute a Dune Analytics query by its ID.
  """
  def dune_query(query_id) do
    get("#{dune_base_url()}/query/#{query_id}/results", dune_headers())
  end

  @doc """
  Execute a Dune Analytics query with parameters.
  """
  def dune_query_with_params(query_id, params) do
    url = "#{dune_base_url()}/query/#{query_id}/results"
    post(url, params, dune_headers())
  end

  @doc """
  Get the status of an executing Dune query.
  """
  def dune_query_status(query_id) do
    get("#{dune_base_url()}/query/#{query_id}/status", dune_headers())
  end

  @doc """
  Cancel a running Dune query execution.
  """
  def dune_cancel_query(execution_id) do
    delete("#{dune_base_url()}/execution/#{execution_id}/cancel", dune_headers())
  end

  # ── Combined Analytics ───────────────────────────────────────────────

  @doc """
  Get comprehensive analytics for a protocol from both DeFiLlama and Dune.
  Returns a map with :defillama and :dune keys.
  """
  def comprehensive_analytics(protocol_slug, dune_query_id \\ nil) do
    defillama_data = protocol_tvl(protocol_slug)

    dune_data =
      if dune_query_id do
        dune_query(dune_query_id)
      else
        %{error: "No Dune query ID provided"}
      end

    %{
      protocol: protocol_slug,
      defillama: defillama_data,
      dune: dune_data,
      fetched_at: DateTime.utc_now()
    }
  end

  @doc """
  Monitor TVL changes for a protocol. Returns current TVL and percentage
  change over the specified period.
  """
  def monitor_tvl_change(protocol_slug, days \\ 7) do
    current = protocol_tvl(protocol_slug)

    case current do
      {:ok, data} ->
        current_tvl = data["tvl"] || 0
        # Get historical for trend
        case protocol_tvl_history(protocol_slug, days) do
          {:ok, history} ->
            tvls = history["chart"] || []
            oldest_tvl = List.last(tvls)
            change_pct =
              if oldest_tvl && oldest_tvl["tvl"] && oldest_tvl["tvl"] > 0 do
                ((current_tvl - oldest_tvl["tvl"]) / oldest_tvl["tvl"]) * 100
              else
                0
              end

            {:ok, %{
              current_tvl: current_tvl,
              change_pct: Float.round(change_pct, 2),
              period_days: days,
              data_points: length(tvls)
            }}

          error -> error
        end

      error -> error
    end
  end

  # ── HTTP helpers ─────────────────────────────────────────────────────

  defp get(url, headers \\ nil) do
    req_headers = headers || defillama_headers()

    req =
      Req.new(
        url: url,
        headers: req_headers,
        receive_timeout: 30_000
      )

    case Req.get(req) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, "HTTP #{status}: #{inspect(body)}"}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  defp post(url, body, headers) do
    req =
      Req.new(
        url: url,
        json: body,
        headers: headers,
        receive_timeout: 60_000
      )

    case Req.post(req) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, "HTTP #{status}: #{inspect(body)}"}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  defp delete(url, headers) do
    req =
      Req.new(
        url: url,
        headers: headers,
        receive_timeout: 15_000
      )

    case Req.delete(req) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, "HTTP #{status}: #{inspect(body)}"}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end
end
