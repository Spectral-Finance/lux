defmodule Lux.YouTube.ContentIntelligence.PerformanceAnalytics do
  @moduledoc """
  Calculates video performance metrics, retention patterns, view velocity,
  and benchmarks against channel historical standards.
  """

  @type performance_summary :: %{
          views: non_neg_integer(),
          watch_time_minutes: float(),
          average_view_duration_seconds: float(),
          average_percentage_viewed: float(),
          engagement_rate: float(),
          views_per_hour: float(),
          velocity_score: float(),
          retention_health: :excellent | :good | :average | :poor,
          hook_retention_rate: float(),
          benchmark_multiplier: float()
        }

  @type retention_point :: %{timestamp_seconds: non_neg_integer(), percentage_retained: float()}

  @doc """
  Evaluates raw video telemetry and calculates performance scores.
  """
  @spec evaluate_performance(map(), map()) :: performance_summary()
  def evaluate_performance(video_stats, channel_baseline \\ %{}) do
    views = Map.get(video_stats, :views, Map.get(video_stats, "views", 0))
    watch_time_seconds = Map.get(video_stats, :watch_time_seconds, Map.get(video_stats, "watch_time_seconds", 0.0))
    duration_seconds = max(Map.get(video_stats, :duration_seconds, Map.get(video_stats, "duration_seconds", 600.0)), 1.0)
    published_hours_ago = max(Map.get(video_stats, :published_hours_ago, Map.get(video_stats, "published_hours_ago", 24.0)), 0.1)

    likes = Map.get(video_stats, :likes, Map.get(video_stats, "likes", 0))
    comments = Map.get(video_stats, :comments, Map.get(video_stats, "comments", 0))
    shares = Map.get(video_stats, :shares, Map.get(video_stats, "shares", 0))

    avd_seconds = if views > 0, do: Float.round(watch_time_seconds / views, 1), else: 0.0
    apv = Float.round(min((avd_seconds / duration_seconds) * 100, 100.0), 2)
    watch_time_minutes = Float.round(watch_time_seconds / 60.0, 2)

    total_engagements = likes + comments + shares
    engagement_rate = if views > 0, do: Float.round((total_engagements / views) * 100, 2), else: 0.0

    vph = Float.round(views / published_hours_ago, 2)

    # Channel baseline multiplier
    avg_channel_views = Map.get(channel_baseline, :avg_views_at_24h, Map.get(channel_baseline, "avg_views_at_24h", 1000.0))
    benchmark_multiplier = if avg_channel_views > 0, do: Float.round(views / avg_channel_views, 2), else: 1.0

    # Hook retention (sample from 30s)
    retention_curve = Map.get(video_stats, :retention_curve, Map.get(video_stats, "retention_curve", []))
    hook_retention = calculate_hook_retention(retention_curve)

    retention_health =
      cond do
        apv >= 55.0 and hook_retention >= 70.0 -> :excellent
        apv >= 42.0 and hook_retention >= 55.0 -> :good
        apv >= 30.0 -> :average
        true -> :poor
      end

    velocity_score = calculate_velocity_score(vph, benchmark_multiplier)

    %{
      views: views,
      watch_time_minutes: watch_time_minutes,
      average_view_duration_seconds: avd_seconds,
      average_percentage_viewed: apv,
      engagement_rate: engagement_rate,
      views_per_hour: vph,
      velocity_score: velocity_score,
      retention_health: retention_health,
      hook_retention_rate: hook_retention,
      benchmark_multiplier: benchmark_multiplier
    }
  end

  @doc """
  Analyzes retention curve drop-offs and identifies drop spikes.
  """
  @spec analyze_retention_curve(list(retention_point())) :: %{
          hook_rate: float(),
          midpoint_rate: float(),
          end_rate: float(),
          major_drop_points: list(non_neg_integer())
        }
  def analyze_retention_curve([]), do: %{hook_rate: 0.0, midpoint_rate: 0.0, end_rate: 0.0, major_drop_points: []}

  def analyze_retention_curve(curve) when is_list(curve) do
    hook = calculate_hook_retention(curve)

    midpoint_entry =
      if length(curve) > 2 do
        Enum.at(curve, div(length(curve), 2))
      else
        nil
      end

    midpoint_rate = if midpoint_entry, do: get_percentage(midpoint_entry), else: 0.0

    last_entry = List.last(curve)
    end_rate = if last_entry, do: get_percentage(last_entry), else: 0.0

    # Detect drops greater than 12% between consecutive sample points
    drops =
      curve
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.filter(fn [p1, p2] ->
        get_percentage(p1) - get_percentage(p2) >= 12.0
      end)
      |> Enum.map(fn [_p1, p2] ->
        Map.get(p2, :timestamp_seconds, Map.get(p2, "timestamp_seconds", 0))
      end)

    %{
      hook_rate: hook,
      midpoint_rate: midpoint_rate,
      end_rate: end_rate,
      major_drop_points: drops
    }
  end

  defp calculate_hook_retention([]), do: 65.0

  defp calculate_hook_retention(curve) do
    # Find data point closest to 30 seconds
    match =
      Enum.find(curve, fn pt ->
        sec = Map.get(pt, :timestamp_seconds, Map.get(pt, "timestamp_seconds", 0))
        sec in 25..35
      end)

    case match do
      nil ->
        case List.first(curve) do
          nil -> 65.0
          pt -> get_percentage(pt)
        end

      pt ->
        get_percentage(pt)
    end
  end

  defp get_percentage(pt) when is_map(pt) do
    Map.get(pt, :percentage_retained, Map.get(pt, "percentage_retained", 0.0))
  end

  defp calculate_velocity_score(vph, multiplier) do
    score = (vph / 50.0) * 0.6 + multiplier * 40.0
    Float.round(min(max(score, 0.0), 100.0), 1)
  end
end
