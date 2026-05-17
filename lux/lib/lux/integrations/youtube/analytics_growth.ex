defmodule Lux.Integrations.YouTube.AnalyticsGrowth do
  @moduledoc """
  Transport-neutral analytics and growth helpers for YouTube channels.

  This module intentionally avoids calling the YouTube API directly. It accepts
  normalized snapshots from any collector and produces deterministic growth,
  retention, revenue, ROI, benchmark, audit, and report payloads that can be
  used by Lux agents, prisms, or beams.
  """

  @type metric_snapshot :: %{
          optional(:views) => number(),
          optional(:watch_time_minutes) => number(),
          optional(:subscribers) => number(),
          optional(:likes) => number(),
          optional(:comments) => number(),
          optional(:shares) => number(),
          optional(:revenue) => number(),
          optional(:cost) => number(),
          optional(:average_view_duration_seconds) => number(),
          optional(:video_duration_seconds) => number(),
          optional(:published_at) => Date.t() | String.t()
        }

  @doc """
  Builds a compact analytics snapshot with common derived metrics.
  """
  @spec snapshot(metric_snapshot()) :: map()
  def snapshot(metrics) when is_map(metrics) do
    views = number(metrics, :views)
    likes = number(metrics, :likes)
    comments = number(metrics, :comments)
    shares = number(metrics, :shares)
    subscribers = number(metrics, :subscribers)
    revenue = number(metrics, :revenue)
    cost = number(metrics, :cost)

    %{
      views: views,
      watch_time_minutes: number(metrics, :watch_time_minutes),
      subscribers: subscribers,
      engagement_rate: ratio(likes + comments + shares, views),
      subscriber_conversion_rate: ratio(subscribers, views),
      revenue: revenue,
      cost: cost,
      roi: ratio(revenue - cost, cost),
      retention_rate: retention_rate(metrics)
    }
  end

  @doc """
  Compares an ordered series of snapshots and returns growth deltas.
  """
  @spec growth_trend([metric_snapshot()]) :: map()
  def growth_trend([]), do: %{points: [], view_growth_rate: 0.0, subscriber_growth_rate: 0.0}

  def growth_trend([single]),
    do: %{points: [snapshot(single)], view_growth_rate: 0.0, subscriber_growth_rate: 0.0}

  def growth_trend(metrics) when is_list(metrics) do
    points = Enum.map(metrics, &snapshot/1)
    first = List.first(points)
    last = List.last(points)

    %{
      points: points,
      view_growth_rate: growth_rate(first.views, last.views),
      subscriber_growth_rate: growth_rate(first.subscribers, last.subscribers),
      revenue_growth_rate: growth_rate(first.revenue, last.revenue)
    }
  end

  @doc """
  Scores competitor/channel benchmarks from normalized snapshots.
  """
  @spec benchmark(metric_snapshot(), [metric_snapshot()]) :: map()
  def benchmark(channel_metrics, competitor_metrics) when is_list(competitor_metrics) do
    channel = snapshot(channel_metrics)
    competitors = Enum.map(competitor_metrics, &snapshot/1)

    averages = %{
      views: average(competitors, :views),
      engagement_rate: average(competitors, :engagement_rate),
      subscriber_conversion_rate: average(competitors, :subscriber_conversion_rate),
      retention_rate: average(competitors, :retention_rate)
    }

    %{
      channel: channel,
      competitor_average: averages,
      relative_view_performance: ratio(channel.views, averages.views),
      relative_engagement_performance: ratio(channel.engagement_rate, averages.engagement_rate),
      relative_retention_performance: ratio(channel.retention_rate, averages.retention_rate)
    }
  end

  @doc """
  Produces a lightweight channel audit with prioritized recommendations.
  """
  @spec audit(metric_snapshot(), keyword()) :: map()
  def audit(metrics, opts \\ []) when is_map(metrics) do
    data = snapshot(metrics)

    thresholds = %{
      engagement_rate: Keyword.get(opts, :min_engagement_rate, 0.03),
      retention_rate: Keyword.get(opts, :min_retention_rate, 0.35),
      subscriber_conversion_rate: Keyword.get(opts, :min_subscriber_conversion_rate, 0.01),
      roi: Keyword.get(opts, :min_roi, 0.0)
    }

    checks = [
      check(
        :engagement,
        data.engagement_rate,
        thresholds.engagement_rate,
        "Improve hooks, CTAs, and comment prompts"
      ),
      check(
        :retention,
        data.retention_rate,
        thresholds.retention_rate,
        "Tighten intro pacing and remove mid-video drop-off points"
      ),
      check(
        :subscriber_conversion,
        data.subscriber_conversion_rate,
        thresholds.subscriber_conversion_rate,
        "Add clearer subscription prompts and series playlists"
      ),
      check(
        :roi,
        data.roi,
        thresholds.roi,
        "Reduce production cost or prioritize higher-converting topics"
      )
    ]

    %{
      snapshot: data,
      passed: Enum.count(checks, & &1.passed),
      failed: Enum.reject(checks, & &1.passed),
      checks: checks
    }
  end

  @doc """
  Forecasts views, subscribers, and revenue with a conservative linear trend.

  The function intentionally stays deterministic and dependency-free so it can
  be used in agents and tests without a model server. It uses the average delta
  between consecutive points and projects the next `periods` periods.
  """
  @spec forecast([metric_snapshot()], pos_integer()) :: [map()]
  def forecast(channel_series, periods \\ 3)

  def forecast(channel_series, periods) when is_list(channel_series) and periods > 0 do
    points = Enum.map(channel_series, &snapshot/1)

    views_delta = average_delta(points, :views)
    subscribers_delta = average_delta(points, :subscribers)
    revenue_delta = average_delta(points, :revenue)
    last = List.last(points) || snapshot(%{})

    Enum.map(1..periods, fn period ->
      %{
        period: period,
        projected_views: non_negative(last.views + views_delta * period),
        projected_subscribers: non_negative(last.subscribers + subscribers_delta * period),
        projected_revenue: non_negative(last.revenue + revenue_delta * period)
      }
    end)
  end

  @doc """
  Estimates revenue optimization opportunities from traffic and monetization inputs.
  """
  @spec revenue_optimization(metric_snapshot(), keyword()) :: map()
  def revenue_optimization(metrics, opts \\ []) when is_map(metrics) do
    data = snapshot(metrics)
    current_rpm = ratio(data.revenue, data.views) * 1000
    target_rpm = number_option(opts, :target_rpm, max(current_rpm, 3.0))
    target_conversion_rate = number_option(opts, :target_subscriber_conversion_rate, 0.02)
    projected_revenue = data.views / 1000 * target_rpm
    projected_subscribers = data.views * target_conversion_rate

    %{
      current_rpm: Float.round(current_rpm, 4),
      target_rpm: Float.round(target_rpm, 4),
      projected_revenue: Float.round(projected_revenue, 2),
      incremental_revenue: Float.round(max(projected_revenue - data.revenue, 0.0), 2),
      projected_subscribers: Float.round(projected_subscribers, 2),
      subscriber_gap: Float.round(max(projected_subscribers - data.subscribers, 0.0), 2),
      recommendations: revenue_recommendations(current_rpm, target_rpm, data)
    }
  end

  @doc """
  Builds an agent-friendly automated report payload.
  """
  @spec report([metric_snapshot()], [metric_snapshot()], keyword()) :: map()
  def report(channel_series, competitors \\ [], opts \\ []) when is_list(channel_series) do
    current = channel_series |> List.last() || %{}
    trend = growth_trend(channel_series)
    audit_result = audit(current, opts)
    forecast_periods = Keyword.get(opts, :forecast_periods, 3)

    %{
      generated_at: Keyword.get(opts, :generated_at, DateTime.utc_now()),
      summary: %{
        view_growth_rate: trend.view_growth_rate,
        subscriber_growth_rate: trend.subscriber_growth_rate,
        revenue_growth_rate: Map.get(trend, :revenue_growth_rate, 0.0),
        failed_audit_checks: Enum.map(audit_result.failed, & &1.name)
      },
      trend: trend,
      forecast: forecast(channel_series, forecast_periods),
      audit: audit_result,
      benchmark: benchmark(current, competitors),
      revenue_optimization: revenue_optimization(current, opts),
      recommendations: recommendations(audit_result.failed)
    }
  end

  defp retention_rate(%{average_view_duration_seconds: avg, video_duration_seconds: duration}),
    do: ratio(avg, duration)

  defp retention_rate(%{
         "average_view_duration_seconds" => avg,
         "video_duration_seconds" => duration
       }),
       do: ratio(avg, duration)

  defp retention_rate(_), do: 0.0

  defp number(map, key) do
    case Map.get(map, key, Map.get(map, Atom.to_string(key), 0)) do
      value when is_integer(value) or is_float(value) -> value * 1.0
      _ -> 0.0
    end
  end

  defp number_option(opts, key, default) do
    case Keyword.get(opts, key, default) do
      value when is_integer(value) or is_float(value) -> value * 1.0
      _ -> default * 1.0
    end
  end

  defp ratio(_, denominator) when denominator == 0, do: 0.0
  defp ratio(numerator, denominator), do: Float.round(numerator / denominator, 4)

  defp growth_rate(0, _), do: 0.0
  defp growth_rate(initial, current), do: ratio(current - initial, initial)

  defp average([], _key), do: 0.0

  defp average(items, key) do
    items
    |> Enum.map(&Map.get(&1, key, 0.0))
    |> Enum.sum()
    |> Kernel./(length(items))
    |> Float.round(4)
  end

  defp average_delta(points, _key) when length(points) < 2, do: 0.0

  defp average_delta(points, key) do
    points
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [previous, current] ->
      Map.get(current, key, 0.0) - Map.get(previous, key, 0.0)
    end)
    |> Enum.sum()
    |> Kernel./(length(points) - 1)
  end

  defp non_negative(value), do: value |> max(0.0) |> Float.round(2)

  defp check(name, actual, minimum, recommendation) do
    %{
      name: name,
      actual: actual,
      minimum: minimum,
      passed: actual >= minimum,
      recommendation: recommendation
    }
  end

  defp recommendations(failed_checks) do
    Enum.map(failed_checks, fn check ->
      %{area: check.name, action: check.recommendation}
    end)
  end

  defp revenue_recommendations(current_rpm, target_rpm, data) do
    [
      current_rpm < target_rpm &&
        %{
          area: :monetization,
          action: "Prioritize high-intent topics, sponsorship slots, and end-screen offers"
        },
      data.subscriber_conversion_rate < 0.02 &&
        %{
          area: :conversion,
          action: "Package videos into series and add subscription CTAs before retention drop-off"
        },
      data.retention_rate < 0.35 &&
        %{
          area: :retention,
          action: "Shorten intros and move the main payoff into the first third of the video"
        }
    ]
    |> Enum.reject(&is_nil/1)
  end
end
