defmodule Lux.Integrations.YouTube.GrowthEngine do
  @moduledoc """
  Deterministic YouTube analytics and growth optimization engine.

  The engine turns a channel brief and recent video metrics into a complete growth report:
  normalized analytics, audience and retention insights, competitor benchmarks, revenue
  opportunities, ROI tracking, growth predictions, experiments, and an automated report.
  It does not call the YouTube API directly, so it can be used in tests, agents, and local
  planning workflows with imported analytics exports.
  """

  @default_period_days 28

  @doc """
  Builds a full analytics report for a YouTube channel.
  """
  def run(input), do: analyze(input)

  def analyze(input) when is_map(input) do
    {:ok,
     %{
       channel_name: string_value(input, :channel_name, "Untitled YouTube channel"),
       period_days: period_days(input),
       analytics_data_collection: collect_metrics(input),
       audience_insights: audience_insights(input),
       trend_analysis: trend_analysis(input),
       growth_prediction: growth_prediction(input),
       revenue_optimization: revenue_optimization(input),
       retention_analysis: retention_optimization(input),
       competitor_analysis: competitive_benchmark(input),
       roi_tracking: roi_tracking(input),
       channel_audit: channel_audit(input),
       automated_report: automated_report(input),
       experiments: experiments(input),
       action_plan: action_plan(input)
     }}
  end

  def analyze(_input), do: {:error, "Expected a map with YouTube analytics data"}

  @doc """
  Normalizes raw video metrics into channel-level analytics and per-video scorecards.
  """
  def collect_metrics(input) do
    videos = normalized_videos(input)
    period_days = period_days(input)

    total_views = sum(videos, :views)
    total_impressions = sum(videos, :impressions)
    total_revenue = sum(videos, :revenue_usd)
    total_subscribers = sum(videos, :subscribers_gained)
    total_watch_time_hours = sum(videos, :watch_time_hours)

    %{
      upload_count: length(videos),
      period_days: period_days,
      totals: %{
        views: total_views,
        impressions: total_impressions,
        revenue_usd: round_number(total_revenue),
        subscribers_gained: total_subscribers,
        watch_time_hours: round_number(total_watch_time_hours)
      },
      rates: %{
        weighted_ctr: ratio(total_views, total_impressions),
        average_retention_rate: average(videos, :retention_rate),
        rpm: rpm(total_revenue, total_views),
        subscribers_per_1k_views: rate_per_1k(total_subscribers, total_views),
        average_daily_views: round_number(total_views / max(period_days, 1)),
        average_daily_revenue_usd: round_number(total_revenue / max(period_days, 1))
      },
      videos: videos,
      top_videos: videos |> Enum.sort_by(& &1.performance_score, :desc) |> Enum.take(3),
      data_quality: data_quality(videos)
    }
  end

  @doc """
  Aggregates audience, topic, and traffic-source signals from the input videos.
  """
  def audience_insights(input) do
    videos = normalized_videos(input)
    topics = topic_counts(videos)
    traffic_sources = weighted_distribution(videos, :traffic_sources)
    audience = weighted_distribution(videos, :audience)

    %{
      top_topics: topics,
      primary_topic: top_key(topics),
      traffic_sources: traffic_sources,
      primary_traffic_source: top_key(traffic_sources),
      audience_segments: audience,
      strongest_audience_segment: top_key(audience),
      recommendations: audience_recommendations(topics, traffic_sources, audience)
    }
  end

  @doc """
  Compares recent and earlier videos to identify directional growth trends.
  """
  def trend_analysis(input) do
    videos = input |> normalized_videos() |> sort_videos()

    case Enum.split(videos, div(length(videos), 2)) do
      {[], _recent} ->
        empty_trend()

      {_prior, []} ->
        empty_trend()

      {prior, recent} ->
        view_growth_rate = growth_rate(average_raw(prior, :views), average_raw(recent, :views))

        revenue_growth_rate =
          growth_rate(average_raw(prior, :revenue_usd), average_raw(recent, :revenue_usd))

        subscriber_growth_rate =
          growth_rate(
            average_raw(prior, :subscribers_gained),
            average_raw(recent, :subscribers_gained)
          )

        %{
          direction: trend_direction(view_growth_rate),
          view_growth_rate: round_number(view_growth_rate),
          revenue_growth_rate: round_number(revenue_growth_rate),
          subscriber_growth_rate: round_number(subscriber_growth_rate),
          recent_average_views: round_number(average_raw(recent, :views)),
          prior_average_views: round_number(average_raw(prior, :views)),
          sample_size: length(videos)
        }
    end
  end

  @doc """
  Projects next-period views, subscribers, and revenue from current velocity and trend.
  """
  def growth_prediction(input) do
    metrics = collect_metrics(input)
    trend = trend_analysis(input)
    period_days = metrics.period_days
    horizon_days = int_value(input, :prediction_horizon_days, 30)

    trend_factor =
      trend
      |> Map.get(:view_growth_rate, 0)
      |> clamp(-0.35, 0.75)

    velocity_multiplier = 1 + trend_factor * 0.5

    %{
      horizon_days: horizon_days,
      projected_views:
        metrics.totals.views
        |> daily_projection(period_days, horizon_days, velocity_multiplier)
        |> round_number(),
      projected_subscribers:
        metrics.totals.subscribers_gained
        |> daily_projection(period_days, horizon_days, velocity_multiplier)
        |> round_number(),
      projected_revenue_usd:
        metrics.totals.revenue_usd
        |> daily_projection(period_days, horizon_days, velocity_multiplier)
        |> round_number(),
      confidence: prediction_confidence(metrics),
      assumptions: [
        "Uses imported channel analytics instead of live YouTube API calls",
        "Projects from current daily velocity adjusted by recent view trend",
        "Assumes upload cadence and monetization mix stay similar during the forecast window"
      ]
    }
  end

  @doc """
  Produces revenue optimization opportunities from RPM, CTR, retention, and goals.
  """
  def revenue_optimization(input) do
    metrics = collect_metrics(input)
    goals = map_value(input, :goals, %{})
    revenue_goal = number_value(goals, :revenue_usd, 0)
    revenue_gap = max(revenue_goal - metrics.totals.revenue_usd, 0)

    %{
      current_revenue_usd: metrics.totals.revenue_usd,
      current_rpm: metrics.rates.rpm,
      revenue_goal_usd: revenue_goal,
      revenue_gap_usd: round_number(revenue_gap),
      priority: revenue_priority(metrics.rates.rpm, revenue_gap),
      opportunities: revenue_opportunities(metrics),
      monetization_tests: [
        "Compare affiliate call-to-action placement in first 30 seconds vs midpoint",
        "Package high-retention topics into sponsor-ready series",
        "Track RPM by topic before increasing upload volume"
      ]
    }
  end

  @doc """
  Highlights videos with weak audience retention and the fixes to test next.
  """
  def retention_optimization(input) do
    metrics = collect_metrics(input)

    weak_videos =
      metrics.videos
      |> Enum.filter(&(&1.retention_rate < 0.45))
      |> Enum.map(&Map.take(&1, [:title, :retention_rate, :views]))

    %{
      average_retention_rate: metrics.rates.average_retention_rate,
      weak_retention_videos: weak_videos,
      recommendations:
        retention_recommendations(metrics.rates.average_retention_rate, weak_videos)
    }
  end

  @doc """
  Benchmarks channel output against competitor snapshots supplied by the caller.
  """
  def competitive_benchmark(input) do
    competitors = list_value(input, :competitors)
    metrics = collect_metrics(input)

    competitor_average_views =
      competitors |> Enum.map(&number_value(&1, :views, 0)) |> average_numbers()

    competitor_average_subscribers =
      competitors |> Enum.map(&number_value(&1, :subscribers_gained, 0)) |> average_numbers()

    competitor_average_uploads =
      competitors |> Enum.map(&number_value(&1, :upload_count, 0)) |> average_numbers()

    %{
      competitor_count: length(competitors),
      average_competitor_views: round_number(competitor_average_views),
      average_competitor_subscribers_gained: round_number(competitor_average_subscribers),
      average_competitor_upload_count: round_number(competitor_average_uploads),
      view_index_vs_competitors: ratio(metrics.totals.views, competitor_average_views),
      subscriber_index_vs_competitors:
        ratio(metrics.totals.subscribers_gained, competitor_average_subscribers),
      upload_index_vs_competitors: ratio(metrics.upload_count, competitor_average_uploads),
      recommendations:
        competitor_recommendations(metrics, competitor_average_views, competitor_average_uploads)
    }
  end

  @doc """
  Tracks simple channel ROI when production cost data is present.
  """
  def roi_tracking(input) do
    metrics = collect_metrics(input)
    cost = number_value(input, :production_cost_usd, 0)
    profit = metrics.totals.revenue_usd - cost

    %{
      production_cost_usd: round_number(cost),
      revenue_usd: metrics.totals.revenue_usd,
      profit_usd: round_number(profit),
      roi: ratio(profit, cost),
      payback_status: if(profit >= 0, do: "profitable", else: "below_payback")
    }
  end

  @doc """
  Automates a channel audit from normalized analytics, revenue, retention, and benchmark data.
  """
  def channel_audit(input) do
    metrics = collect_metrics(input)
    retention = retention_optimization(input)
    benchmark = competitive_benchmark(input)
    score = audit_score(metrics, benchmark)

    findings =
      [
        metrics.data_quality.status != "complete" && "analytics_import_needs_cleanup",
        metrics.rates.weighted_ctr < 0.05 && "packaging_ctr_below_target",
        metrics.rates.average_retention_rate < 0.5 && "retention_below_target",
        metrics.rates.rpm < 5 && "rpm_below_target",
        benchmark.competitor_count > 0 && benchmark.view_index_vs_competitors < 1 &&
          "views_below_competitor_average",
        length(retention.weak_retention_videos) > 0 && "weak_retention_videos_present"
      ]
      |> Enum.filter(& &1)

    %{
      score: score,
      grade: audit_grade(score),
      findings: findings,
      recommended_focus: audit_focus(findings),
      recurring_checks: [
        "Confirm analytics import completeness",
        "Review CTR and retention before scaling upload cadence",
        "Compare RPM and views against competitor snapshots",
        "Refresh ROI and revenue gap after each reporting period"
      ]
    }
  end

  @doc """
  Creates the automated report payload an agent can send to a team or dashboard.
  """
  def automated_report(input) do
    metrics = collect_metrics(input)
    prediction = growth_prediction(input)
    revenue = revenue_optimization(input)
    retention = retention_optimization(input)
    benchmark = competitive_benchmark(input)

    %{
      title: "#{string_value(input, :channel_name, "YouTube channel")} growth report",
      summary: [
        "#{metrics.totals.views} views and #{metrics.totals.subscribers_gained} subscribers gained in #{metrics.period_days} days",
        "Projected #{prediction.projected_views} views and $#{prediction.projected_revenue_usd} revenue over #{prediction.horizon_days} days",
        "Revenue priority: #{revenue.priority}; retention rate: #{retention.average_retention_rate}"
      ],
      scorecard: %{
        growth_direction: trend_analysis(input).direction,
        weighted_ctr: metrics.rates.weighted_ctr,
        average_retention_rate: metrics.rates.average_retention_rate,
        rpm: metrics.rates.rpm,
        view_index_vs_competitors: benchmark.view_index_vs_competitors
      },
      alerts: report_alerts(metrics, revenue, retention),
      next_report_sections: [
        "Analytics data collection",
        "Growth prediction",
        "Revenue optimization",
        "Audience retention",
        "Competitor benchmark",
        "ROI tracking",
        "Channel audit"
      ]
    }
  end

  @doc """
  Suggests growth experiments tied to the weakest current metric.
  """
  def experiments(input) do
    metrics = collect_metrics(input)

    [
      %{
        name: "Thumbnail and title CTR test",
        metric: "weighted_ctr",
        baseline: metrics.rates.weighted_ctr,
        hypothesis: "Sharper outcome-driven titles will improve browse CTR"
      },
      %{
        name: "First-minute retention test",
        metric: "average_retention_rate",
        baseline: metrics.rates.average_retention_rate,
        hypothesis: "Moving proof and payoff before the intro will reduce early drop-off"
      },
      %{
        name: "Revenue call-to-action test",
        metric: "rpm",
        baseline: metrics.rates.rpm,
        hypothesis: "Topic-specific offers will lift RPM without reducing retention"
      }
    ]
  end

  defp action_plan(input) do
    metrics = collect_metrics(input)
    revenue = revenue_optimization(input)
    retention = retention_optimization(input)

    [
      "Publish more videos in #{audience_insights(input).primary_topic || "the top-performing topic"}",
      "Fix retention on #{length(retention.weak_retention_videos)} underperforming videos before scaling volume",
      "Prioritize #{revenue.priority} revenue work while tracking RPM by topic",
      "Review the automated report every #{max(div(metrics.period_days, 4), 1)} days"
    ]
  end

  defp normalized_videos(input) do
    input
    |> list_value(:videos)
    |> Enum.map(&normalize_video/1)
  end

  defp normalize_video(video) when is_map(video) do
    views = int_value(video, :views, 0)
    impressions = int_value(video, :impressions, 0)
    revenue = number_value(video, :revenue_usd, 0)
    avg_duration = number_value(video, :average_view_duration_seconds, 0)
    duration = number_value(video, :duration_seconds, 0)
    subscribers = int_value(video, :subscribers_gained, 0)

    ctr =
      cond do
        impressions > 0 -> ratio(views, impressions)
        number_value(video, :ctr, 0) > 0 -> number_value(video, :ctr, 0)
        true -> 0
      end

    retention =
      cond do
        duration > 0 -> ratio(avg_duration, duration)
        number_value(video, :retention_rate, 0) > 0 -> number_value(video, :retention_rate, 0)
        true -> 0
      end

    %{
      title: string_value(video, :title, "Untitled video"),
      published_at: value(video, :published_at),
      views: views,
      impressions: impressions,
      ctr: ctr,
      average_view_duration_seconds: round_number(avg_duration),
      duration_seconds: round_number(duration),
      retention_rate: retention,
      subscribers_gained: subscribers,
      subscribers_per_1k_views: rate_per_1k(subscribers, views),
      revenue_usd: round_number(revenue),
      rpm: rpm(revenue, views),
      watch_time_hours: round_number(views * avg_duration / 3600),
      traffic_sources: map_value(video, :traffic_sources, %{}),
      topics: list_value(video, :topics),
      audience: map_value(video, :audience, %{}),
      performance_score:
        performance_score(ctr, retention, rpm(revenue, views), rate_per_1k(subscribers, views))
    }
  end

  defp normalize_video(_video), do: normalize_video(%{})

  defp data_quality([]) do
    %{status: "missing", notes: ["No videos supplied"]}
  end

  defp data_quality(videos) do
    missing_impressions = Enum.count(videos, &(&1.impressions == 0))
    missing_revenue = Enum.count(videos, &(&1.revenue_usd == 0))

    %{
      status: if(missing_impressions == 0, do: "complete", else: "partial"),
      notes:
        [
          missing_impressions > 0 && "#{missing_impressions} videos missing impressions",
          missing_revenue > 0 && "#{missing_revenue} videos missing revenue"
        ]
        |> Enum.filter(& &1)
    }
  end

  defp revenue_opportunities(metrics) do
    [
      metrics.rates.rpm < 5 && "Lift RPM with sponsor packages or affiliate offers on top topics",
      metrics.rates.weighted_ctr < 0.05 &&
        "Improve thumbnails and titles before increasing paid promotion",
      metrics.rates.average_retention_rate < 0.5 &&
        "Raise retention before adding mid-roll or sponsor reads",
      metrics.rates.subscribers_per_1k_views < 20 &&
        "Add clearer subscription prompts around high-value moments"
    ]
    |> Enum.filter(& &1)
    |> case do
      [] -> ["Scale current monetization mix while monitoring RPM by topic"]
      opportunities -> opportunities
    end
  end

  defp retention_recommendations(retention_rate, weak_videos) do
    [
      retention_rate < 0.5 && "Move the core payoff into the first minute",
      length(weak_videos) > 0 &&
        "Rewrite intros for weak-retention videos before producing sequels",
      "Compare retention by topic before setting the next content calendar"
    ]
    |> Enum.filter(& &1)
  end

  defp audience_recommendations(topics, traffic_sources, audience) do
    [
      top_key(topics) && "Build the next series around #{top_key(topics)}",
      top_key(traffic_sources) && "Optimize packaging for #{top_key(traffic_sources)} traffic",
      top_key(audience) && "Localize examples and calls-to-action for #{top_key(audience)}"
    ]
    |> Enum.filter(& &1)
  end

  defp competitor_recommendations(_metrics, 0, _competitor_uploads) do
    ["Add competitor snapshots to enable performance benchmarking"]
  end

  defp competitor_recommendations(metrics, competitor_views, competitor_uploads) do
    [
      metrics.totals.views < competitor_views &&
        "Close the view gap by cloning top-topic packaging, not upload volume alone",
      metrics.upload_count < competitor_uploads &&
        "Test a higher upload cadence only after retention is stable",
      metrics.totals.views >= competitor_views &&
        "Protect the current lead with recurring formats and faster reporting"
    ]
    |> Enum.filter(& &1)
  end

  defp report_alerts(metrics, revenue, retention) do
    [
      metrics.data_quality.status == "partial" &&
        "Analytics import is missing fields for some videos",
      revenue.revenue_gap_usd > 0 && "Revenue is $#{revenue.revenue_gap_usd} below goal",
      length(retention.weak_retention_videos) > 0 &&
        "#{length(retention.weak_retention_videos)} videos need retention fixes"
    ]
    |> Enum.filter(& &1)
  end

  defp topic_counts(videos) do
    videos
    |> Enum.flat_map(& &1.topics)
    |> Enum.frequencies()
  end

  defp weighted_distribution(videos, key) do
    totals =
      Enum.reduce(videos, %{}, fn video, acc ->
        Enum.reduce(Map.get(video, key, %{}), acc, fn {name, share}, inner_acc ->
          weighted_share = number_value(%{share: share}, :share, 0) * max(video.views, 1)
          Map.update(inner_acc, to_string(name), weighted_share, &(&1 + weighted_share))
        end)
      end)

    total = totals |> Map.values() |> Enum.sum()

    if total == 0 do
      %{}
    else
      Map.new(totals, fn {key, value} -> {key, ratio(value, total)} end)
    end
  end

  defp sort_videos(videos) do
    Enum.sort_by(videos, fn video ->
      case Date.from_iso8601(to_string(video.published_at || "")) do
        {:ok, date} -> Date.to_erl(date)
        _ -> {9999, 12, 31}
      end
    end)
  end

  defp empty_trend do
    %{
      direction: "insufficient_data",
      view_growth_rate: 0,
      revenue_growth_rate: 0,
      subscriber_growth_rate: 0,
      recent_average_views: 0,
      prior_average_views: 0,
      sample_size: 0
    }
  end

  defp trend_direction(rate) when rate > 0.1, do: "up"
  defp trend_direction(rate) when rate < -0.1, do: "down"
  defp trend_direction(_rate), do: "flat"

  defp revenue_priority(rpm_value, revenue_gap) do
    cond do
      revenue_gap > 0 and rpm_value < 5 -> "monetization_foundation"
      revenue_gap > 0 -> "revenue_gap"
      rpm_value < 5 -> "rpm_lift"
      true -> "scale"
    end
  end

  defp prediction_confidence(metrics) do
    base = min(metrics.upload_count / 8, 1) * 0.5
    impressions = if metrics.totals.impressions > 0, do: 0.25, else: 0
    revenue = if metrics.totals.revenue_usd > 0, do: 0.25, else: 0

    round_number(base + impressions + revenue)
  end

  defp performance_score(ctr, retention, rpm_value, subscribers_per_1k) do
    score =
      ctr * 35 + retention * 35 + min(rpm_value / 20, 1) * 15 +
        min(subscribers_per_1k / 50, 1) * 15

    round_number(score)
  end

  defp audit_score(metrics, benchmark) do
    ctr_score = min(metrics.rates.weighted_ctr / 0.08, 1) * 25
    retention_score = min(metrics.rates.average_retention_rate / 0.6, 1) * 25
    rpm_score = min(metrics.rates.rpm / 20, 1) * 20
    conversion_score = min(metrics.rates.subscribers_per_1k_views / 35, 1) * 15

    benchmark_score =
      if benchmark.competitor_count > 0 do
        min(benchmark.view_index_vs_competitors, 1) * 15
      else
        7.5
      end

    round_number(ctr_score + retention_score + rpm_score + conversion_score + benchmark_score, 2)
  end

  defp audit_grade(score) when score >= 85, do: "A"
  defp audit_grade(score) when score >= 70, do: "B"
  defp audit_grade(score) when score >= 55, do: "C"
  defp audit_grade(_score), do: "D"

  defp audit_focus([]), do: "scale_current_growth_system"
  defp audit_focus(["analytics_import_needs_cleanup" | _rest]), do: "analytics_collection"
  defp audit_focus(["packaging_ctr_below_target" | _rest]), do: "packaging"
  defp audit_focus(["retention_below_target" | _rest]), do: "retention"
  defp audit_focus(["rpm_below_target" | _rest]), do: "monetization"
  defp audit_focus(["views_below_competitor_average" | _rest]), do: "competitive_positioning"
  defp audit_focus(["weak_retention_videos_present" | _rest]), do: "retention"

  defp daily_projection(total, period_days, horizon_days, multiplier) do
    total / max(period_days, 1) * horizon_days * multiplier
  end

  defp growth_rate(0, current) when current > 0, do: 1
  defp growth_rate(0, _current), do: 0
  defp growth_rate(previous, current), do: (current - previous) / previous

  defp rpm(revenue, views), do: rate_per_1k(revenue, views)
  defp rate_per_1k(value, base), do: round_number(ratio(value, base) * 1000)

  defp ratio(_value, base) when base in [0, 0.0], do: 0
  defp ratio(value, base), do: round_number(value / base)

  defp average([], _key), do: 0
  defp average(values, key), do: values |> average_raw(key) |> round_number()

  defp average_raw([], _key), do: 0
  defp average_raw(values, key), do: sum(values, key) / length(values)

  defp average_numbers([]), do: 0
  defp average_numbers(values), do: Enum.sum(values) / length(values)

  defp sum(values, key), do: values |> Enum.map(&Map.get(&1, key, 0)) |> Enum.sum()

  defp top_key(values) when map_size(values) == 0, do: nil
  defp top_key(values), do: values |> Enum.max_by(fn {_key, value} -> value end) |> elem(0)

  defp period_days(input), do: max(int_value(input, :period_days, @default_period_days), 1)

  defp list_value(input, key) do
    case value(input, key, []) do
      values when is_list(values) -> values
      value when is_binary(value) -> [value]
      _ -> []
    end
  end

  defp map_value(input, key, default) do
    case value(input, key, default) do
      value when is_map(value) -> value
      _ -> default
    end
  end

  defp string_value(input, key, default) do
    case value(input, key, default) do
      value when is_binary(value) -> value
      value when is_atom(value) -> Atom.to_string(value)
      value when is_number(value) -> to_string(value)
      _ -> default
    end
  end

  defp int_value(input, key, default) do
    input
    |> number_value(key, default)
    |> round()
  end

  defp number_value(input, key, default) do
    case value(input, key, default) do
      value when is_integer(value) ->
        value

      value when is_float(value) ->
        value

      value when is_binary(value) ->
        case Float.parse(value) do
          {number, _rest} -> number
          :error -> default
        end

      _ ->
        default
    end
  end

  defp value(input, key, default \\ nil)

  defp value(input, key, default) when is_map(input) do
    Map.get(input, key, Map.get(input, to_string(key), default))
  end

  defp value(_input, _key, default), do: default

  defp round_number(value, precision \\ 4)
  defp round_number(value, _precision) when is_integer(value), do: value
  defp round_number(value, precision) when is_float(value), do: Float.round(value, precision)
  defp round_number(value, _precision), do: value

  defp clamp(value, min, _max) when value < min, do: min
  defp clamp(value, _min, max) when value > max, do: max
  defp clamp(value, _min, _max), do: value
end
