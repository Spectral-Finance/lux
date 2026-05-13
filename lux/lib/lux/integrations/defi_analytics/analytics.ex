defmodule Lux.Integrations.DeFiAnalytics.Analytics do
  @moduledoc """
  Deterministic DeFi analytics processing, dashboard, and alert helpers.
  """

  alias Lux.Integrations.DeFiAnalytics.Client

  @doc "Collects protocol records from DeFiLlama."
  def collect_protocol_metrics(opts \\ %{}) do
    with {:ok, rows} <- Client.protocols(opts) do
      {:ok, process_protocols(rows)}
    end
  end

  @doc "Collects and processes one protocol's TVL and volume metrics."
  def collect_protocol(slug, opts \\ %{}) do
    with {:ok, protocol} <- Client.protocol(slug, opts) do
      {:ok, process_protocol(protocol)}
    end
  end

  @doc "Collects DeFiLlama DEX volume overview metrics."
  def collect_volume_metrics(opts \\ %{}) do
    with {:ok, payload} <- Client.dex_volume_overview(opts) do
      {:ok, process_volume_overview(payload)}
    end
  end

  @doc "Collects one DEX protocol's DeFiLlama volume history."
  def collect_protocol_volume(slug, opts \\ %{}) do
    with {:ok, payload} <- Client.dex_volume_summary(slug, opts) do
      {:ok, process_volume_summary(payload)}
    end
  end

  @doc "Normalizes DeFiLlama protocol list rows."
  def process_protocols(rows) when is_list(rows) do
    rows
    |> Enum.map(&protocol_summary/1)
    |> Enum.sort_by(& &1.tvl_usd, :desc)
  end

  @doc "Normalizes one DeFiLlama protocol payload."
  def process_protocol(payload) when is_map(payload) do
    tvl_series = value(payload, :tvl) |> normalize_series(:date, :total_liquidity_usd)
    volume_series = value(payload, :totalDataChart) |> normalize_pair_series(:date, :volume_usd)

    %{
      name: value(payload, :name),
      slug: value(payload, :slug),
      category: value(payload, :category),
      chains: value(payload, :chains) || [],
      current_tvl_usd:
        payload |> value(:currentChainTvls) |> sum_values(fallback: number(payload, :tvl)),
      tvl_series: tvl_series,
      volume_series: volume_series,
      tvl_change_7d_pct: pct_change(tvl_series, :total_liquidity_usd, 7),
      volume_change_7d_pct: pct_change(volume_series, :volume_usd, 7)
    }
  end

  @doc "Normalizes DeFiLlama DEX volume overview rows."
  def process_volume_overview(%{"protocols" => rows}), do: process_volume_overview(rows)
  def process_volume_overview(%{protocols: rows}), do: process_volume_overview(rows)

  def process_volume_overview(rows) when is_list(rows) do
    rows
    |> Enum.map(&volume_summary/1)
    |> Enum.sort_by(& &1.total_24h_usd, :desc)
  end

  def process_volume_overview(_payload), do: []

  @doc "Normalizes one DeFiLlama DEX volume summary payload."
  def process_volume_summary(payload) when is_map(payload) do
    volume_series = value(payload, :totalDataChart) |> normalize_pair_series(:date, :volume_usd)

    %{
      name: value(payload, :name),
      display_name: value(payload, :displayName),
      slug: value(payload, :slug),
      chains: value(payload, :chains) || [],
      total_24h_usd: number(payload, :total24h),
      total_7d_usd: number(payload, :total7d),
      total_30d_usd: number(payload, :total30d),
      volume_series: volume_series,
      volume_change_7d_pct: pct_change(volume_series, :volume_usd, 7),
      chain_breakdown_24h: value(payload, :breakdown24h) || %{}
    }
  end

  @doc "Filters and ranks yield pools."
  def yield_analytics(pools, opts \\ %{}) do
    min_tvl = number(opts, :min_tvl_usd)
    chain = value(opts, :chain)

    pools
    |> pool_rows()
    |> Enum.filter(
      &(is_nil(chain) or String.downcase(to_string(&1.chain)) == String.downcase(to_string(chain)))
    )
    |> Enum.filter(&(&1.tvl_usd >= min_tvl))
    |> Enum.sort_by(& &1.risk_adjusted_apy, :desc)
  end

  @doc "Normalizes Dune result rows for custom query support."
  def process_dune_result(%{"result" => %{"rows" => rows}}), do: rows
  def process_dune_result(%{result: %{rows: rows}}), do: rows
  def process_dune_result(%{"rows" => rows}), do: rows
  def process_dune_result(%{rows: rows}), do: rows
  def process_dune_result(rows) when is_list(rows), do: rows
  def process_dune_result(_result), do: []

  @doc "Builds protocol-level dashboard data."
  def dashboard(protocols, yields, opts \\ %{}) do
    protocols = process_protocols(protocols)
    yields = yield_analytics(yields, opts)
    volumes = opts |> value(:volumes) |> process_volume_overview()

    %{
      totals: %{
        protocols: length(protocols),
        tvl_usd: protocols |> Enum.map(& &1.tvl_usd) |> Enum.sum(),
        yield_pools: length(yields),
        volume_protocols: length(volumes),
        volume_24h_usd: volumes |> Enum.map(& &1.total_24h_usd) |> Enum.sum()
      },
      top_protocols: Enum.take(protocols, 10),
      top_yields: Enum.take(yields, 10),
      top_volumes: Enum.take(volumes, 10),
      alerts: alerts(%{protocols: protocols, yields: yields, volumes: volumes}, opts)
    }
  end

  @doc "Creates alert events for analytics thresholds."
  def alerts(data, opts \\ %{}) do
    tvl_drop_pct = abs(default_number(opts, :tvl_drop_pct, 10.0))
    volume_drop_pct = abs(default_number(opts, :volume_drop_pct, tvl_drop_pct))
    min_yield_apy = default_number(opts, :min_yield_apy, 20.0)
    protocols = value(data, :protocols) || []
    yields = value(data, :yields) || []
    volumes = value(data, :volumes) || []

    tvl_alerts =
      protocols
      |> Enum.filter(
        &(number(&1, :change_1d_pct) <= -tvl_drop_pct or
            number(&1, :change_7d_pct) <= -tvl_drop_pct)
      )
      |> Enum.map(
        &%{type: :tvl_drop, severity: :high, subject: &1.slug || &1.name, value: &1.change_7d_pct}
      )

    yield_alerts =
      yields
      |> Enum.filter(&(&1.apy >= min_yield_apy))
      |> Enum.map(&%{type: :high_yield, severity: :medium, subject: &1.pool, value: &1.apy})

    volume_alerts =
      volumes
      |> Enum.filter(&(&1.change_7d_pct <= -volume_drop_pct))
      |> Enum.map(
        &%{
          type: :volume_drop,
          severity: :medium,
          subject: &1.slug || &1.name,
          value: &1.change_7d_pct
        }
      )

    tvl_alerts ++ yield_alerts ++ volume_alerts
  end

  defp protocol_summary(row) do
    %{
      name: value(row, :name),
      slug: value(row, :slug),
      category: value(row, :category),
      chains: value(row, :chains) || [],
      tvl_usd: number(row, :tvl),
      change_1d_pct: number(row, :change_1d),
      change_7d_pct: number(row, :change_7d),
      mcap_usd: number(row, :mcap)
    }
  end

  defp volume_summary(row) do
    %{
      name: value(row, :name),
      display_name: value(row, :displayName),
      slug: value(row, :slug),
      chains: value(row, :chains) || [],
      total_24h_usd: number(row, :total24h),
      total_7d_usd: number(row, :total7d),
      total_30d_usd: number(row, :total30d),
      change_1d_pct: number(row, :change_1d),
      change_7d_pct: number(row, :change_7d),
      chain_breakdown_24h: value(row, :breakdown24h) || %{}
    }
  end

  defp pool_rows(%{"data" => rows}), do: pool_rows(rows)
  defp pool_rows(%{data: rows}), do: pool_rows(rows)

  defp pool_rows(rows) when is_list(rows) do
    Enum.map(rows, fn row ->
      apy = number(row, :apy)
      tvl = number(row, :tvlUsd)

      %{
        pool: value(row, :pool),
        project: value(row, :project),
        chain: value(row, :chain),
        symbol: value(row, :symbol),
        tvl_usd: tvl,
        apy: apy,
        apy_base: number(row, :apyBase),
        apy_reward: number(row, :apyReward),
        risk_adjusted_apy: risk_adjusted_apy(apy, tvl, number(row, :ilRisk))
      }
    end)
  end

  defp pool_rows(_rows), do: []

  defp normalize_series(rows, date_key, value_key) when is_list(rows) do
    Enum.map(rows, fn row ->
      %{
        date_key => value(row, :date),
        value_key => first_number(row, [:totalLiquidityUSD, :tvl])
      }
    end)
  end

  defp normalize_series(_rows, _date_key, _value_key), do: []

  defp normalize_pair_series(rows, date_key, value_key) when is_list(rows) do
    Enum.map(rows, fn
      [date, amount] ->
        %{date_key => date, value_key => number_value(amount)}

      {date, amount} ->
        %{date_key => date, value_key => number_value(amount)}

      row when is_map(row) ->
        %{date_key => value(row, :date), value_key => first_number(row, [:value, :volume])}

      _row ->
        %{date_key => nil, value_key => 0.0}
    end)
  end

  defp normalize_pair_series(_rows, _date_key, _value_key), do: []

  defp pct_change(series, key, periods) do
    values = series |> Enum.map(&number(&1, key)) |> Enum.reject(&(&1 == 0))

    case {Enum.at(values, -periods - 1), List.last(values)} do
      {nil, _latest} -> 0.0
      {0, _latest} -> 0.0
      {first, latest} when is_number(latest) -> Float.round((latest - first) / first * 100, 2)
      _ -> 0.0
    end
  end

  defp risk_adjusted_apy(apy, tvl, il_risk) do
    tvl_penalty = if tvl < 1_000_000, do: 0.8, else: 1.0
    il_penalty = if il_risk > 0, do: 0.85, else: 1.0
    Float.round(apy * tvl_penalty * il_penalty, 2)
  end

  defp sum_values(map, _opts) when is_map(map),
    do: map |> Map.values() |> Enum.map(&number_value/1) |> Enum.sum()

  defp sum_values(_value, opts), do: Keyword.get(opts, :fallback, 0.0)

  defp default_number(map, key, default) do
    case value(map, key) do
      nil -> default
      value -> number_value(value)
    end
  end

  defp first_number(map, keys) do
    keys
    |> Enum.map(&number(map, &1))
    |> Enum.find(&(&1 != 0.0))
    |> Kernel.||(0.0)
  end

  defp number(map, key), do: value(map, key) |> number_value()
  defp number_value(nil), do: 0.0
  defp number_value(value) when is_integer(value), do: value * 1.0
  defp number_value(value) when is_float(value), do: value
  defp number_value(value) when is_binary(value), do: value |> Float.parse() |> elem_or_zero()
  defp number_value(_value), do: 0.0
  defp elem_or_zero({number, _rest}), do: number
  defp elem_or_zero(:error), do: 0.0

  defp value(map, key) when is_map(map), do: Map.get(map, key) || Map.get(map, to_string(key))
  defp value(data, key) when is_list(data), do: Keyword.get(data, key)
  defp value(_map, _key), do: nil
end
