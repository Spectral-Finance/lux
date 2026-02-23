defmodule Lux.Prisms.YouTube.GenerateGrowthReport do
  @moduledoc """
  A prism for generating a structured YouTube channel growth report.

  Produces an executive summary, key metrics, growth rate estimation,
  revenue projections (based on typical CPM of $2-$5 per 1,000 views),
  strategic recommendations, and concrete next steps.

  This prism performs local computation only — no external API calls.

  ## Examples

      iex> GenerateGrowthReport.handler(%{
      ...>   "channel_id" => "UCxxxxxx",
      ...>   "channel_stats" => %{
      ...>     "subscriber_count" => 75_000,
      ...>     "view_count" => 5_000_000,
      ...>     "video_count" => 220,
      ...>     "avg_views_per_video" => 22_727
      ...>   },
      ...>   "time_period" => "monthly"
      ...> }, %{})
      {:ok, %{
        channel_id: "UCxxxxxx",
        time_period: "monthly",
        executive_summary: "...",
        key_metrics: %{...},
        growth_rate: %{...},
        revenue_estimates: %{...},
        recommendations: [...],
        next_steps: [...]
      }}
  """

  use Lux.Prism,
    name: "Generate YouTube Growth Report",
    description: "Produces a structured growth report with revenue estimates and strategic recommendations",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "YouTube channel ID (optional, for reference in report)"
        },
        channel_stats: %{
          type: :object,
          description: "Channel statistics map (subscriber_count, view_count, video_count, avg_views_per_video)",
          properties: %{
            subscriber_count: %{type: :integer},
            view_count: %{type: :integer},
            video_count: %{type: :integer},
            avg_views_per_video: %{type: :integer}
          },
          required: ["subscriber_count", "view_count", "video_count"]
        },
        time_period: %{
          type: :string,
          description: "Reporting period for projections",
          enum: ["weekly", "monthly", "quarterly"],
          default: "monthly"
        }
      },
      required: ["channel_stats"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string},
        time_period: %{type: :string},
        executive_summary: %{type: :string},
        key_metrics: %{type: :object},
        growth_rate: %{type: :object},
        revenue_estimates: %{type: :object},
        recommendations: %{type: :array, items: %{type: :string}},
        next_steps: %{type: :array, items: %{type: :string}}
      },
      required: ["executive_summary", "key_metrics", "revenue_estimates", "recommendations", "next_steps"]
    }

  require Logger

  @cpm_low 2.0
  @cpm_high 5.0

  def handler(params, agent) do
    agent_name = get_in(agent, [:agent, :name]) || agent[:name] || "Unknown"
    Logger.info("Agent #{agent_name} generating growth report")

    channel_id = params["channel_id"] || params[:channel_id]
    time_period = params["time_period"] || params[:time_period] || "monthly"
    stats = params["channel_stats"] || params[:channel_stats] || %{}

    subscriber_count = stats["subscriber_count"] || stats[:subscriber_count] || 0
    view_count = stats["view_count"] || stats[:view_count] || 0
    video_count = stats["video_count"] || stats[:video_count] || 0
    avg_views = stats["avg_views_per_video"] || stats[:avg_views_per_video] ||
      (if video_count > 0, do: div(view_count, video_count), else: 0)

    {period_multiplier, period_label} = period_config(time_period)

    key_metrics = %{
      subscriber_count: subscriber_count,
      total_views: view_count,
      video_count: video_count,
      avg_views_per_video: avg_views,
      subscriber_to_view_ratio: if(view_count > 0, do: Float.round(subscriber_count / view_count * 100, 3), else: 0.0)
    }

    monthly_growth_rate = estimate_monthly_growth_rate(subscriber_count)
    period_growth_rate = monthly_growth_rate * period_multiplier
    projected_subscribers = round(subscriber_count * (1 + period_growth_rate / 100))

    growth_rate = %{
      estimated_monthly_growth_percent: Float.round(monthly_growth_rate, 2),
      estimated_period_growth_percent: Float.round(period_growth_rate, 2),
      period: period_label,
      projected_subscribers: projected_subscribers
    }

    period_views = round(avg_views * videos_per_period(time_period))
    revenue_low = Float.round(period_views / 1000 * @cpm_low, 2)
    revenue_high = Float.round(period_views / 1000 * @cpm_high, 2)

    revenue_estimates = %{
      period: period_label,
      estimated_period_views: period_views,
      cpm_range_usd: %{low: @cpm_low, high: @cpm_high},
      estimated_revenue_usd: %{low: revenue_low, high: revenue_high},
      annual_revenue_usd: %{
        low: Float.round(revenue_low * (12 / period_multiplier), 2),
        high: Float.round(revenue_high * (12 / period_multiplier), 2)
      },
      note: "Estimates based on typical CPM of $#{@cpm_low}-$#{@cpm_high}/1,000 views. Actual varies by niche, audience geography, and seasonality."
    }

    recommendations = build_recommendations(subscriber_count, avg_views, video_count)
    next_steps = build_next_steps(time_period, subscriber_count)
    summary = build_summary(subscriber_count, avg_views, period_label, revenue_low, revenue_high, projected_subscribers)

    {:ok, %{
      channel_id: channel_id,
      time_period: time_period,
      executive_summary: summary,
      key_metrics: key_metrics,
      growth_rate: growth_rate,
      revenue_estimates: revenue_estimates,
      recommendations: recommendations,
      next_steps: next_steps
    }}
  end

  defp period_config("weekly"), do: {0.25, "weekly"}
  defp period_config("quarterly"), do: {3.0, "quarterly"}
  defp period_config(_), do: {1.0, "monthly"}

  defp videos_per_period("weekly"), do: 1
  defp videos_per_period("quarterly"), do: 13
  defp videos_per_period(_), do: 4

  defp estimate_monthly_growth_rate(subs) when subs >= 1_000_000, do: 2.0
  defp estimate_monthly_growth_rate(subs) when subs >= 100_000, do: 4.0
  defp estimate_monthly_growth_rate(subs) when subs >= 10_000, do: 6.0
  defp estimate_monthly_growth_rate(subs) when subs >= 1_000, do: 8.0
  defp estimate_monthly_growth_rate(_), do: 12.0

  defp build_summary(subs, avg_views, period, rev_low, rev_high, projected_subs) do
    tier = channel_tier(subs)
    "#{tier} channel with #{format_number(subs)} subscribers and an average of " <>
    "#{format_number(avg_views)} views per video. #{String.capitalize(period)} revenue " <>
    "estimated at $#{rev_low}-$#{rev_high}. Projected subscriber count by end of period: " <>
    "#{format_number(projected_subs)}."
  end

  defp build_recommendations(subs, avg_views, video_count) do
    base = [
      "Optimise video SEO: use high-volume keywords in titles, descriptions, and tags",
      "Maintain a consistent upload schedule (minimum 1 video per week for growth)",
      "Engage with the audience via Community posts between video uploads"
    ]

    subs_recs = cond do
      subs < 1_000 -> ["Focus on niche authority content to establish credibility"]
      subs < 10_000 -> ["Run a subscriber milestone campaign (e.g., 10K countdown)"]
      subs < 100_000 -> ["Collaborate with creators in adjacent niches for audience crossover"]
      true -> ["Diversify revenue streams: memberships, sponsorships, merchandise"]
    end

    view_recs = if avg_views < 5_000 do
      ["A/B test thumbnails to improve click-through rates (target > 5%)"]
    else
      ["Convert top-performing videos into Shorts to expand reach"]
    end

    upload_recs = if video_count < 50 do
      ["Build a content backlog before increasing promotion spend"]
    else
      []
    end

    base ++ subs_recs ++ view_recs ++ upload_recs
  end

  defp build_next_steps("weekly", subs) do
    ["Plan and script next week's video content",
     "Review this week's analytics for retention drop-off points",
     "Reply to all new comments to boost engagement signals"] ++ milestone_step(subs)
  end
  defp build_next_steps("quarterly", subs) do
    ["Set quarterly subscriber and view targets in a tracking spreadsheet",
     "Schedule at least one collaboration for the quarter",
     "Review monetisation eligibility if not yet partnered"] ++ milestone_step(subs)
  end
  defp build_next_steps(_, subs) do
    ["Audit last month's top 3 and bottom 3 videos to identify patterns",
     "Update underperforming video thumbnails and titles",
     "Submit one video to a relevant online community (Reddit, Discord)"] ++ milestone_step(subs)
  end

  defp milestone_step(subs) do
    next = next_milestone(subs)
    ["Work toward next subscriber milestone: #{next}"]
  end

  defp channel_tier(subs) when subs >= 1_000_000, do: "Established"
  defp channel_tier(subs) when subs >= 100_000, do: "Growing"
  defp channel_tier(subs) when subs >= 10_000, do: "Rising"
  defp channel_tier(subs) when subs >= 1_000, do: "Emerging"
  defp channel_tier(_), do: "New"

  defp format_number(n) when is_float(n), do: format_number(round(n))
  defp format_number(n) when n >= 1_000_000, do: "#{Float.round(n / 1_000_000.0, 1)}M"
  defp format_number(n) when n >= 1_000, do: "#{Float.round(n / 1_000.0, 1)}K"
  defp format_number(n), do: "#{n}"

  defp next_milestone(n) when n < 1_000, do: "1K"
  defp next_milestone(n) when n < 10_000, do: "10K"
  defp next_milestone(n) when n < 100_000, do: "100K"
  defp next_milestone(n) when n < 1_000_000, do: "1M"
  defp next_milestone(_), do: "10M"
end
