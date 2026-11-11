defmodule Lux.Lenses.DefiAnalytics.DefillamaDuneLens do
  @moduledoc """
  DeFiLlama & Dune Analytics Protocol Intelligence Lens (#88).

  Capabilities:
  - Protocol & chain TVL tracking (`analyze_protocol_tvl/1`) with 1d/7d/30d growth and chain dominance
  - Risk-adjusted yield pool filtering and ranking (`rank_yield_pools/2`)
  - Parameterized Dune Analytics query execution payload construction & DEX volume aggregation (`build_dune_query/2`, `summarize_dex_volume/1`)
  - Threshold-based TVL drawdown and volume anomaly alerting (`evaluate_alerts/2`)
  """

  @doc """
  Computes TVL growth metrics, chain breakdown percentages, and mcap/TVL valuation ratio from DeFiLlama protocol snapshots.
  """
  @spec analyze_protocol_tvl(map()) :: {:ok, map()} | {:error, atom()}
  def analyze_protocol_tvl(%{name: name, current_tvl_usd: cur_tvl} = snapshot)
      when is_binary(name) and is_number(cur_tvl) and cur_tvl > 0 do
    tvl_7d_ago = Map.get(snapshot, :tvl_7d_ago_usd, cur_tvl)
    tvl_30d_ago = Map.get(snapshot, :tvl_30d_ago_usd, cur_tvl)
    mcap_usd = Map.get(snapshot, :mcap_usd, 0.0)
    chain_tvls = Map.get(snapshot, :chain_tvls, %{})

    change_7d_pct =
      if tvl_7d_ago > 0, do: (cur_tvl - tvl_7d_ago) / tvl_7d_ago * 100.0, else: 0.0

    change_30d_pct =
      if tvl_30d_ago > 0, do: (cur_tvl - tvl_30d_ago) / tvl_30d_ago * 100.0, else: 0.0

    chain_shares =
      Enum.into(chain_tvls, %{}, fn {chain, val} ->
        {chain, Float.round(val / cur_tvl * 100.0, 2)}
      end)

    mcap_to_tvl = if mcap_usd > 0, do: Float.round(mcap_usd / cur_tvl, 4), else: nil

    {:ok,
     %{
       protocol: name,
       current_tvl_usd: Float.round(cur_tvl * 1.0, 2),
       change_7d_pct: Float.round(change_7d_pct, 2),
       change_30d_pct: Float.round(change_30d_pct, 2),
       chain_dominance_pct: chain_shares,
       mcap_to_tvl: mcap_to_tvl
     }}
  end

  def analyze_protocol_tvl(_), do: {:error, :invalid_tvl_snapshot}

  @doc """
  Filters and ranks DeFiLlama yield pools by TVL floor and risk-adjusted Sharpe-like yield score.
  """
  @spec rank_yield_pools([map()], keyword()) :: {:ok, [map()]}
  def rank_yield_pools(pools, opts \\ []) when is_list(pools) do
    min_tvl = Keyword.get(opts, :min_tvl_usd, 1_000_000.0)
    stablecoin_only = Keyword.get(opts, :stablecoin_only, false)

    ranked =
      pools
      |> Enum.filter(fn p ->
        tvl_ok = Map.get(p, :tvl_usd, 0.0) >= min_tvl
        stable_ok = if stablecoin_only, do: Map.get(p, :stablecoin, false) == true, else: true
        tvl_ok and stable_ok
      end)
      |> Enum.map(fn p ->
        apy = Map.get(p, :apy, 0.0) * 1.0
        sigma = max(0.25, Map.get(p, :apy_sigma, 1.0) * 1.0)
        risk_adjusted_score = apy / sigma
        Map.put(p, :risk_adjusted_score, Float.round(risk_adjusted_score, 4))
      end)
      |> Enum.sort_by(& &1.risk_adjusted_score, :desc)

    {:ok, ranked}
  end

  @doc """
  Constructs a Dune Analytics v1 query execution request payload with typed parameters and performance tier.
  """
  @spec build_dune_query(pos_integer(), map(), String.t()) :: {:ok, map()} | {:error, atom()}
  def build_dune_query(query_id, params \\ %{}, performance \\ "medium")
      when is_integer(query_id) and query_id > 0 and is_map(params) do
    if performance not in ["medium", "large"] do
      {:error, :invalid_performance_tier}
    else
      {:ok,
       %{
         endpoint: "https://api.dune.com/api/v1/query/#{query_id}/execute",
         query_id: query_id,
         query_parameters: params,
         performance: performance
       }}
    end
  end

  @doc """
  Aggregates daily DEX volume rows returned by Dune Analytics or DeFiLlama and detects volume spikes.
  """
  @spec summarize_dex_volume([map()]) :: {:ok, map()} | {:error, atom()}
  def summarize_dex_volume(rows) when is_list(rows) and length(rows) > 0 do
    volumes = Enum.map(rows, &(Map.get(&1, :volume_usd, 0.0) * 1.0))
    total_vol = Enum.sum(volumes)
    avg_vol = total_vol / length(volumes)
    latest_vol = List.last(volumes)
    spike_ratio = if avg_vol > 0, do: latest_vol / avg_vol, else: 1.0

    {:ok,
     %{
       days_count: length(volumes),
       total_volume_usd: Float.round(total_vol, 2),
       average_daily_volume_usd: Float.round(avg_vol, 2),
       latest_daily_volume_usd: Float.round(latest_vol, 2),
       volume_spike_ratio: Float.round(spike_ratio, 4)
     }}
  end

  def summarize_dex_volume(_), do: {:error, :empty_volume_series}

  @doc """
  Generates actionable alerts when TVL drops below threshold or DEX volume spikes abnormally.
  """
  @spec evaluate_alerts(map(), map()) :: {:ok, [map()]}
  def evaluate_alerts(tvl_summary, volume_summary) do
    alerts = []

    alerts =
      if Map.get(tvl_summary, :change_7d_pct, 0.0) <= -10.0 do
        [
          %{
            severity: :critical,
            type: :tvl_drawdown,
            message:
              "Protocol #{tvl_summary[:protocol]} TVL dropped #{tvl_summary[:change_7d_pct]}% over 7d"
          }
          | alerts
        ]
      else
        alerts
      end

    alerts =
      if Map.get(volume_summary, :volume_spike_ratio, 1.0) >= 2.0 do
        [
          %{
            severity: :info,
            type: :volume_anomaly,
            message:
              "Daily DEX volume spiked #{volume_summary[:volume_spike_ratio]}x above average"
          }
          | alerts
        ]
      else
        alerts
      end

    {:ok, Enum.reverse(alerts)}
  end
end
