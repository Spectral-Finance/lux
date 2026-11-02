defmodule Lux.YouTube.GrowthEngine.MetricsTracker do
  @moduledoc """
  Collects, aggregates, and computes advanced channel performance metrics,
  monetization efficiency (RPM/CPM), and overall growth momentum.
  """

  @type telemetry_window :: %{
          views: non_neg_integer(),
          watch_time_hours: float(),
          subscribers_gained: non_neg_integer(),
          subscribers_lost: non_neg_integer(),
          net_subscribers: integer(),
          impressions: non_neg_integer(),
          clicks: non_neg_integer(),
          click_through_rate: float(),
          estimated_revenue_usd: float(),
          rpm: float(),
          cpm: float(),
          conversion_rate_per_10k_views: float(),
          momentum_score: float()
        }

  @doc """
  Computes aggregated telemetry metrics from raw channel telemetry data.
  """
  @spec track_window(map()) :: telemetry_window()
  def track_window(raw_data) when is_map(raw_data) do
    views = max(get_val(raw_data, :views, 0), 0)
    watch_time_seconds = get_val(raw_data, :watch_time_seconds, 0.0)
    watch_time_hours = Float.round(watch_time_seconds / 3600.0, 2)

    subs_gained = max(get_val(raw_data, :subscribers_gained, 0), 0)
    subs_lost = max(get_val(raw_data, :subscribers_lost, 0), 0)
    net_subs = subs_gained - subs_lost

    impressions = max(get_val(raw_data, :impressions, 0), 0)
    clicks = max(get_val(raw_data, :clicks, 0), 0)

    ctr =
      if impressions > 0 do
        Float.round((clicks / impressions) * 100, 2)
      else
        0.0
      end

    revenue = Float.round(get_val(raw_data, :estimated_revenue_usd, 0.0), 2)

    rpm =
      if views > 0 do
        Float.round((revenue / views) * 1000.0, 2)
      else
        0.0
      end

    cpm = Float.round(get_val(raw_data, :playback_cpm, rpm * 1.8), 2)

    sub_conv =
      if views > 0 do
        Float.round((net_subs / views) * 10_000.0, 2)
      else
        0.0
      end

    momentum = calculate_momentum(views, net_subs, ctr, rpm)

    %{
      views: views,
      watch_time_hours: watch_time_hours,
      subscribers_gained: subs_gained,
      subscribers_lost: subs_lost,
      net_subscribers: net_subs,
      impressions: impressions,
      clicks: clicks,
      click_through_rate: ctr,
      estimated_revenue_usd: revenue,
      rpm: rpm,
      cpm: cpm,
      conversion_rate_per_10k_views: sub_conv,
      momentum_score: momentum
    }
  end

  defp calculate_momentum(views, net_subs, ctr, rpm) do
    v_component = min(views / 5_000.0, 30.0)
    s_component = min(max(net_subs * 0.2, 0.0), 30.0)
    ctr_component = min(ctr * 3.5, 20.0)
    rpm_component = min(rpm * 2.5, 20.0)

    Float.round(min(v_component + s_component + ctr_component + rpm_component, 100.0), 1)
  end

  defp get_val(map, key, default) do
    Map.get(map, key, Map.get(map, to_string(key), default))
  end
end
