defmodule Lux.Integrations.YouTube.AnalyticsGrowth do
  @moduledoc """
  YouTube analytics and growth optimization helpers.

  The module consumes channel or video metric snapshots from YouTube Analytics,
  exports, warehouses, or tests. It normalizes those snapshots and produces
  growth forecasts, retention analysis, revenue optimization data, competitor
  benchmarks, ROI tracking, and report-ready payloads.
  """

  @type snapshot :: %{
          required(:id) => String.t(),
          required(:captured_at) => DateTime.t(),
          required(:views) => non_neg_integer(),
          optional(:watch_time_minutes) => number(),
          optional(:subscribers_gained) => integer(),
          optional(:revenue_usd) => number(),
          optional(:impressions) => non_neg_integer(),
          optional(:clicks) => non_neg_integer(),
          optional(:average_view_duration_seconds) => number(),
          optional(:video_length_seconds) => number(),
          optional(:production_cost_usd) => number(),
          optional(:metadata) => map()
        }

  @spec normalize_snapshot(map()) :: {:ok, snapshot()} | {:error, String.t()}
  def normalize_snapshot(attrs) when is_map(attrs) do
    with {:ok, id} <- required_string(attrs, :id, [:video_id, :channel_id]),
         {:ok, captured_at} <-
           normalize_datetime(get_value(attrs, :captured_at, DateTime.utc_now())),
         {:ok, views} <- non_negative_integer(attrs, :views, 0),
         {:ok, impressions} <- non_negative_integer(attrs, :impressions, 0),
         {:ok, clicks} <- non_negative_integer(attrs, :clicks, 0) do
      {:ok,
       %{
         id: id,
         title: blank_to_nil(get_value(attrs, :title)),
         captured_at: captured_at,
         views: views,
         watch_time_minutes: number(attrs, :watch_time_minutes, 0.0),
         subscribers_gained: integer(attrs, :subscribers_gained, 0),
         revenue_usd: number(attrs, :revenue_usd, 0.0),
         impressions: impressions,
         clicks: clicks,
         likes: number(attrs, :likes, 0),
         comments: number(attrs, :comments, 0),
         shares: number(attrs, :shares, 0),
         average_view_duration_seconds: number(attrs, :average_view_duration_seconds, 0.0),
         video_length_seconds: number(attrs, :video_length_seconds, 0.0),
         production_cost_usd: number(attrs, :production_cost_usd, 0.0),
         metadata: get_value(attrs, :metadata, %{})
       }}
    end
  end

  def normalize_snapshot(_), do: {:error, "snapshot must be a map"}

  @spec normalize_snapshots([map()]) :: {:ok, [snapshot()]} | {:error, String.t()}
  def normalize_snapshots(snapshots) when is_list(snapshots) do
    snapshots
    |> Enum.reduce_while({:ok, []}, fn snapshot, {:ok, acc} ->
      case normalize_snapshot(snapshot) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, normalized} -> {:ok, Enum.sort_by(normalized, & &1.captured_at, DateTime)}
      error -> error
    end
  end

  def normalize_snapshots(_), do: {:error, "snapshots must be a list"}

  @spec collect_metrics([map()]) :: {:ok, map()} | {:error, String.t()}
  def collect_metrics(snapshots) do
    with {:ok, normalized} <- normalize_snapshots(snapshots) do
      latest_by_id =
        normalized
        |> Enum.group_by(& &1.id)
        |> Map.new(fn {id, items} -> {id, Enum.max_by(items, & &1.captured_at, DateTime)} end)

      totals =
        latest_by_id
        |> Map.values()
        |> Enum.reduce(
          %{
            views: 0,
            watch_time_minutes: 0.0,
            subscribers_gained: 0,
            revenue_usd: 0.0,
            impressions: 0,
            clicks: 0
          },
          fn snapshot, acc ->
            %{
              views: acc.views + snapshot.views,
              watch_time_minutes: acc.watch_time_minutes + snapshot.watch_time_minutes,
              subscribers_gained: acc.subscribers_gained + snapshot.subscribers_gained,
              revenue_usd: acc.revenue_usd + snapshot.revenue_usd,
              impressions: acc.impressions + snapshot.impressions,
              clicks: acc.clicks + snapshot.clicks
            }
          end
        )

      {:ok,
       %{
         total_videos: map_size(latest_by_id),
         totals: totals,
         ctr: safe_div(totals.clicks, totals.impressions),
         rpm: safe_div(totals.revenue_usd * 1000, totals.views),
         by_content: latest_by_id
       }}
    end
  end

  @spec growth_prediction([map()], keyword()) :: {:ok, map()} | {:error, String.t()}
  def growth_prediction(snapshots, opts \\ []) do
    horizon_days = Keyword.get(opts, :horizon_days, 30)

    with {:ok, normalized} <- normalize_snapshots(snapshots) do
      predictions =
        normalized
        |> Enum.group_by(& &1.id)
        |> Map.new(fn {id, items} ->
          ordered = Enum.sort_by(items, & &1.captured_at, DateTime)
          first = List.first(ordered)
          last = List.last(ordered)
          days = max(1, DateTime.diff(last.captured_at, first.captured_at, :day))

          views_per_day = (last.views - first.views) / days
          revenue_per_day = (last.revenue_usd - first.revenue_usd) / days
          subs_per_day = (last.subscribers_gained - first.subscribers_gained) / days

          {id,
           %{
             horizon_days: horizon_days,
             projected_views: round(max(0, last.views + views_per_day * horizon_days)),
             projected_revenue_usd:
               Float.round(max(0.0, last.revenue_usd + revenue_per_day * horizon_days), 2),
             projected_subscribers_gained:
               round(max(0, last.subscribers_gained + subs_per_day * horizon_days)),
             model: "linear_snapshot_delta",
             confidence: confidence(length(ordered), days)
           }}
        end)

      {:ok, predictions}
    end
  end

  @spec retention_analysis([map()]) :: {:ok, [map()]} | {:error, String.t()}
  def retention_analysis(snapshots) do
    with {:ok, normalized} <- normalize_snapshots(snapshots) do
      {:ok,
       Enum.map(normalized, fn snapshot ->
         retention =
           if snapshot.video_length_seconds > 0 do
             snapshot.average_view_duration_seconds / snapshot.video_length_seconds
           else
             0.0
           end

         %{
           id: snapshot.id,
           average_view_duration_seconds: snapshot.average_view_duration_seconds,
           video_length_seconds: snapshot.video_length_seconds,
           retention_percent: Float.round(retention * 100, 2),
           flag: retention_flag(retention)
         }
       end)}
    end
  end

  @spec revenue_optimization([map()]) :: {:ok, map()} | {:error, String.t()}
  def revenue_optimization(snapshots) do
    with {:ok, metrics} <- collect_metrics(snapshots) do
      totals = metrics.totals

      roi =
        safe_div(
          totals.revenue_usd - total_cost(metrics.by_content),
          total_cost(metrics.by_content)
        )

      {:ok,
       %{
         rpm: metrics.rpm,
         ctr: metrics.ctr,
         roi: roi,
         recommendations:
           []
           |> maybe_add(metrics.rpm < 1.5, "Review monetization mix; RPM is below 1.50 USD.")
           |> maybe_add(
             metrics.ctr < 0.04,
             "Run thumbnail and title tests; click-through rate is below 4%."
           )
           |> maybe_add(
             roi < 0.2,
             "Reduce production cost or prioritize higher-return topics; ROI is below 20%."
           )
           |> default_recommendation(
             "Revenue and ROI metrics are within the configured baseline."
           )
       }}
    end
  end

  @spec benchmark([map()], [map()]) :: {:ok, map()} | {:error, String.t()}
  def benchmark(snapshots, competitors \\ []) do
    with {:ok, metrics} <- collect_metrics(snapshots) do
      competitor_rows =
        Enum.map(competitors, fn competitor ->
          views = number(competitor, :views, 0)
          revenue = number(competitor, :revenue_usd, 0.0)

          %{
            name: get_value(competitor, :name, "competitor"),
            views: views,
            rpm: safe_div(revenue * 1000, views)
          }
        end)

      {:ok,
       %{
         own_views: metrics.totals.views,
         own_rpm: metrics.rpm,
         competitors: competitor_rows,
         rank_by_views: rank(metrics.totals.views, Enum.map(competitor_rows, & &1.views)),
         rank_by_rpm: rank(metrics.rpm, Enum.map(competitor_rows, & &1.rpm))
       }}
    end
  end

  @spec channel_audit([map()], keyword()) :: {:ok, map()} | {:error, String.t()}
  def channel_audit(snapshots, opts \\ []) do
    min_ctr = Keyword.get(opts, :min_ctr, 0.04)
    min_retention = Keyword.get(opts, :min_retention, 0.35)

    with {:ok, metrics} <- collect_metrics(snapshots),
         {:ok, retention} <- retention_analysis(snapshots) do
      avg_retention =
        retention |> Enum.map(fn item -> item.retention_percent / 100 end) |> average()

      {:ok,
       %{
         checks: [
           %{name: "ctr", ok: metrics.ctr >= min_ctr, value: metrics.ctr, target: min_ctr},
           %{
             name: "retention",
             ok: avg_retention >= min_retention,
             value: avg_retention,
             target: min_retention
           },
           %{
             name: "revenue_tracking",
             ok: metrics.totals.revenue_usd > 0,
             value: metrics.totals.revenue_usd,
             target: "> 0"
           }
         ],
         recommendations:
           []
           |> maybe_add(metrics.ctr < min_ctr, "Improve packaging; CTR is below target.")
           |> maybe_add(
             avg_retention < min_retention,
             "Tighten intros and pacing; retention is below target."
           )
           |> maybe_add(
             metrics.totals.revenue_usd == 0,
             "Connect revenue data to enable ROI and RPM reporting."
           )
           |> default_recommendation("Channel audit passed the configured thresholds.")
       }}
    end
  end

  @spec report([map()], keyword()) :: {:ok, map()} | {:error, String.t()}
  def report(snapshots, opts \\ []) do
    with {:ok, metrics} <- collect_metrics(snapshots),
         {:ok, prediction} <-
           growth_prediction(snapshots, horizon_days: Keyword.get(opts, :horizon_days, 30)),
         {:ok, retention} <- retention_analysis(snapshots),
         {:ok, revenue} <- revenue_optimization(snapshots),
         {:ok, audit} <- channel_audit(snapshots) do
      {:ok,
       %{
         analytics_data: metrics,
         growth_prediction: prediction,
         retention_analysis: retention,
         revenue_optimization: revenue,
         automated_report: %{
           generated_at: DateTime.utc_now(),
           summary: summary(metrics),
           audit: audit,
           chart_data: %{
             views_by_content: chart_data(metrics.by_content, :views),
             revenue_by_content: chart_data(metrics.by_content, :revenue_usd)
           }
         }
       }}
    end
  end

  defp required_string(attrs, key, aliases) do
    keys = [key | aliases]

    keys
    |> Enum.map(&get_value(attrs, &1))
    |> Enum.find(&present?/1)
    |> case do
      value when is_binary(value) -> {:ok, value}
      value when not is_nil(value) -> {:ok, to_string(value)}
      _ -> {:error, "Missing required #{key}"}
    end
  end

  defp non_negative_integer(attrs, key, default) do
    value = get_value(attrs, key, default)

    cond do
      is_integer(value) and value >= 0 -> {:ok, value}
      is_float(value) and value >= 0 -> {:ok, round(value)}
      true -> {:error, "#{key} must be a non-negative integer"}
    end
  end

  defp normalize_datetime(%DateTime{} = datetime), do: {:ok, datetime}

  defp normalize_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> {:ok, datetime}
      _ -> {:error, "captured_at must be an ISO-8601 timestamp"}
    end
  end

  defp normalize_datetime(_), do: {:error, "captured_at must be a DateTime or ISO-8601 timestamp"}

  defp number(attrs, key, default) do
    case get_value(attrs, key, default) do
      value when is_integer(value) or is_float(value) ->
        value

      value when is_binary(value) ->
        case Float.parse(value) do
          {parsed, _} -> parsed
          :error -> default
        end

      _ ->
        default
    end
  end

  defp integer(attrs, key, default) do
    attrs
    |> number(key, default)
    |> round()
  end

  defp confidence(points, days) when points >= 2 and days >= 7, do: "medium"
  defp confidence(points, _days) when points >= 2, do: "low"
  defp confidence(_, _), do: "insufficient_history"

  defp retention_flag(value) when value >= 0.5, do: "strong"
  defp retention_flag(value) when value >= 0.35, do: "watch"
  defp retention_flag(_), do: "weak"

  defp total_cost(by_content) do
    by_content
    |> Map.values()
    |> Enum.map(& &1.production_cost_usd)
    |> Enum.sum()
  end

  defp rank(value, values), do: Enum.count(values, &(&1 > value)) + 1
  defp average([]), do: 0.0
  defp average(values), do: Enum.sum(values) / length(values)
  defp safe_div(_num, denom) when denom == 0, do: 0.0
  defp safe_div(num, denom), do: num / denom

  defp summary(metrics),
    do:
      "Tracked #{metrics.total_videos} videos with #{metrics.totals.views} total views and #{Float.round(metrics.rpm, 2)} RPM."

  defp chart_data(by_content, field),
    do:
      by_content
      |> Enum.map(fn {id, snapshot} -> %{label: id, value: Map.get(snapshot, field)} end)

  defp maybe_add(items, true, item), do: [item | items]
  defp maybe_add(items, false, _item), do: items
  defp default_recommendation([], item), do: [item]
  defp default_recommendation(items, _item), do: Enum.reverse(items)

  defp get_value(attrs, key, default \\ nil),
    do: Map.get(attrs, key, Map.get(attrs, to_string(key), default))

  defp blank_to_nil(value) when is_binary(value),
    do: if(String.trim(value) == "", do: nil, else: String.trim(value))

  defp blank_to_nil(value), do: value
  defp present?(value), do: not is_nil(blank_to_nil(value))
end
