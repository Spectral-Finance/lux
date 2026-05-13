defmodule Lux.Integrations.YouTube.GrowthEngine do
  @moduledoc """
  YouTube analytics and growth optimization helpers.

  The module normalizes metric snapshots, projects growth, compares competitor
  performance, summarizes retention and ROI, audits channel health, and builds
  automated report payloads.
  """

  @metric_keys [:views, :watch_time_hours, :subscribers, :revenue, :impressions, :clicks, :likes, :comments]

  @doc """
  Normalizes a channel metric snapshot.
  """
  @spec snapshot(map()) :: map()
  def snapshot(metrics) when is_map(metrics) do
    base =
      Enum.reduce(@metric_keys, %{}, fn key, acc ->
        Map.put(acc, key, number(metrics, key))
      end)

    base
    |> Map.merge(%{
      captured_at: value(metrics, :captured_at),
      ctr: ratio(base.clicks, base.impressions),
      engagement_rate: ratio(base.likes + base.comments, max(base.views, 1)),
      revenue_per_1k_views: ratio(base.revenue, max(base.views, 1)) * 1_000
    })
  end

  @doc """
  Projects future growth from historical snapshots using a linear delta.
  """
  @spec growth_projection([map()], non_neg_integer()) :: map()
  def growth_projection(snapshots, periods \\ 7) when is_list(snapshots) do
    normalized = snapshots |> Enum.map(&snapshot/1) |> Enum.sort_by(&(&1.captured_at || ""))
    first = List.first(normalized) || snapshot(%{})
    last = List.last(normalized) || snapshot(%{})
    divisor = max(length(normalized) - 1, 1)

    %{
      periods: periods,
      views: projection(first.views, last.views, divisor, periods),
      subscribers: projection(first.subscribers, last.subscribers, divisor, periods),
      revenue: projection(first.revenue, last.revenue, divisor, periods),
      watch_time_hours: projection(first.watch_time_hours, last.watch_time_hours, divisor, periods)
    }
  end

  @doc """
  Benchmarks channel metrics against competitors.
  """
  @spec competitor_benchmark(map(), [map()]) :: map()
  def competitor_benchmark(channel, competitors) when is_map(channel) and is_list(competitors) do
    channel_snapshot = snapshot(channel)
    competitor_snapshots = Enum.map(competitors, &snapshot/1)

    averages = %{
      views: average(competitor_snapshots, :views),
      engagement_rate: average(competitor_snapshots, :engagement_rate),
      ctr: average(competitor_snapshots, :ctr),
      revenue_per_1k_views: average(competitor_snapshots, :revenue_per_1k_views)
    }

    %{
      channel: channel_snapshot,
      competitor_average: averages,
      gaps: %{
        views: channel_snapshot.views - averages.views,
        engagement_rate: channel_snapshot.engagement_rate - averages.engagement_rate,
        ctr: channel_snapshot.ctr - averages.ctr,
        revenue_per_1k_views: channel_snapshot.revenue_per_1k_views - averages.revenue_per_1k_views
      }
    }
  end

  @doc """
  Summarizes audience retention points.
  """
  @spec retention_summary([map()]) :: map()
  def retention_summary(points) when is_list(points) do
    normalized =
      Enum.map(points, fn point ->
        %{second: number(point, :second), retained_ratio: number(point, :retained_ratio)}
      end)

    %{
      average_retention: average(normalized, :retained_ratio),
      first_drop_second: first_drop(normalized),
      sample_count: length(normalized)
    }
  end

  @doc """
  Summarizes revenue, spend, and ROI.
  """
  @spec roi_summary(map()) :: map()
  def roi_summary(attrs) when is_map(attrs) do
    revenue = number(attrs, :revenue)
    production_cost = number(attrs, :production_cost)
    promotion_cost = number(attrs, :promotion_cost)
    total_cost = production_cost + promotion_cost

    %{
      revenue: revenue,
      production_cost: production_cost,
      promotion_cost: promotion_cost,
      total_cost: total_cost,
      profit: revenue - total_cost,
      roi: ratio(revenue - total_cost, max(total_cost, 1))
    }
  end

  @doc """
  Audits channel health from analytics metrics.
  """
  @spec audit(map()) :: [map()]
  def audit(metrics) when is_map(metrics) do
    snap = snapshot(metrics)

    []
    |> maybe_issue(snap.ctr < 0.04, :ctr, :high, "Improve title and thumbnail packaging")
    |> maybe_issue(snap.engagement_rate < 0.03, :engagement, :medium, "Add stronger comment and subscribe prompts")
    |> maybe_issue(snap.revenue_per_1k_views < 1.0, :revenue, :medium, "Review monetization mix and sponsorship opportunities")
    |> maybe_issue(snap.watch_time_hours < 10, :watch_time, :low, "Increase session depth with playlists and end screens")
    |> Enum.reverse()
  end

  @doc """
  Builds an automated analytics report payload.
  """
  @spec report(map()) :: map()
  def report(attrs) when is_map(attrs) do
    snapshots = value(attrs, :snapshots) || []
    latest = List.last(snapshots) || %{}

    %{
      generated_at: value(attrs, :generated_at) || DateTime.utc_now(),
      channel_id: value(attrs, :channel_id),
      latest_snapshot: snapshot(latest),
      projection: growth_projection(snapshots, value(attrs, :projection_periods) || 7),
      benchmark: competitor_benchmark(latest, value(attrs, :competitors) || []),
      retention: retention_summary(value(attrs, :retention_points) || []),
      roi: roi_summary(value(attrs, :roi) || %{}),
      audit: audit(latest)
    }
  end

  defp projection(first, last, divisor, periods), do: last + (last - first) / divisor * periods

  defp first_drop(points) do
    points
    |> Enum.find(&(&1.retained_ratio < 0.5))
    |> case do
      nil -> nil
      point -> point.second
    end
  end

  defp maybe_issue(issues, false, _area, _severity, _message), do: issues
  defp maybe_issue(issues, true, area, severity, message), do: [%{area: area, severity: severity, message: message} | issues]

  defp average([], _key), do: 0.0
  defp average(items, key), do: items |> Enum.map(&Map.get(&1, key, 0)) |> Enum.sum() |> ratio(length(items))

  defp ratio(_numerator, 0), do: 0.0
  defp ratio(numerator, denominator), do: numerator / denominator

  defp number(map, key) do
    case value(map, key) do
      value when is_integer(value) -> value
      value when is_float(value) -> value
      value when is_binary(value) ->
        case Float.parse(value) do
          {parsed, _rest} -> parsed
          :error -> 0
        end

      _other ->
        0
    end
  end

  defp value(map, key) when is_map(map), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))
  defp value(_map, _key), do: nil
end
