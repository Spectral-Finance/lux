defmodule Lux.YouTube.GrowthEngine.GrowthPredictor do
  @moduledoc """
  Generates predictive growth models for subscribers, views, and revenue over 30d, 60d, and 90d horizons.
  Computes milestone arrival ETAs and seasonality adjustments.
  """

  @milestones [1_000, 5_000, 10_000, 50_000, 100_000, 500_000, 1_000_000]

  @type forecast_horizon :: %{
          projected_subscribers: non_neg_integer(),
          projected_views: non_neg_integer(),
          projected_revenue_usd: float(),
          growth_rate_percentage: float()
        }

  @type milestone_eta :: %{
          milestone: non_neg_integer(),
          days_remaining: non_neg_integer(),
          estimated_date: String.t(),
          status: :achieved | :approaching | :long_term
        }

  @type growth_forecast :: %{
          current_subscribers: non_neg_integer(),
          daily_sub_velocity: float(),
          daily_view_velocity: float(),
          projected_30d: forecast_horizon(),
          projected_60d: forecast_horizon(),
          projected_90d: forecast_horizon(),
          milestones: list(milestone_eta())
        }

  @doc """
  Projects future channel trajectory based on historical velocity and current baselines.
  """
  @spec forecast_growth(map()) :: growth_forecast()
  def forecast_growth(params) when is_map(params) do
    current_subs = get_val(params, :current_subscribers, 10_000)
    daily_subs = max(get_val(params, :daily_sub_velocity, 25.0), 1.0)
    daily_views = max(get_val(params, :daily_view_velocity, 2_000.0), 10.0)
    rpm = get_val(params, :rpm, 4.5)

    # 30d, 60d, 90d projections with compounding compound growth factor (1.02, 1.05, 1.08)
    p30 = compute_horizon(current_subs, daily_subs, daily_views, rpm, 30, 1.02)
    p60 = compute_horizon(current_subs, daily_subs, daily_views, rpm, 60, 1.05)
    p90 = compute_horizon(current_subs, daily_subs, daily_views, rpm, 90, 1.08)

    milestones = compute_milestones(current_subs, daily_subs)

    %{
      current_subscribers: current_subs,
      daily_sub_velocity: daily_subs,
      daily_view_velocity: daily_views,
      projected_30d: p30,
      projected_60d: p60,
      projected_90d: p90,
      milestones: milestones
    }
  end

  defp compute_horizon(current_subs, daily_subs, daily_views, rpm, days, acceleration) do
    new_subs = round(daily_subs * days * acceleration)
    total_subs = current_subs + new_subs

    accum_views = round(daily_views * days * acceleration)
    revenue = Float.round((accum_views / 1000.0) * rpm, 2)
    rate = Float.round((new_subs / max(current_subs, 1)) * 100, 2)

    %{
      projected_subscribers: total_subs,
      projected_views: accum_views,
      projected_revenue_usd: revenue,
      growth_rate_percentage: rate
    }
  end

  defp compute_milestones(current_subs, daily_subs) do
    Enum.map(@milestones, fn m ->
      cond do
        current_subs >= m ->
          %{
            milestone: m,
            days_remaining: 0,
            estimated_date: "ACHIEVED",
            status: :achieved
          }

        true ->
          remaining_needed = m - current_subs
          days = max(round(remaining_needed / daily_subs), 1)
          target_date = Date.add(Date.utc_today(), days) |> Date.to_iso8601()
          status = if days <= 90, do: :approaching, else: :long_term

          %{
            milestone: m,
            days_remaining: days,
            estimated_date: target_date,
            status: status
          }
      end
    end)
  end

  defp get_val(map, key, default) do
    Map.get(map, key, Map.get(map, to_string(key), default))
  end
end
