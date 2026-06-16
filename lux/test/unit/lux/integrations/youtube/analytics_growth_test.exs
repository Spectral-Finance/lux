defmodule Lux.Integrations.YouTube.AnalyticsGrowthTest do
  use UnitCase, async: true

  alias Lux.Integrations.YouTube.AnalyticsGrowth

  @snapshots [
    %{
      id: "video-1",
      title: "Intro",
      captured_at: "2026-06-01T00:00:00Z",
      views: 1_000,
      watch_time_minutes: 800,
      subscribers_gained: 20,
      revenue_usd: 12.0,
      impressions: 10_000,
      clicks: 600,
      average_view_duration_seconds: 120,
      video_length_seconds: 300,
      production_cost_usd: 50
    },
    %{
      id: "video-1",
      captured_at: "2026-06-08T00:00:00Z",
      views: 2_400,
      watch_time_minutes: 1_900,
      subscribers_gained: 60,
      revenue_usd: 32.0,
      impressions: 20_000,
      clicks: 1_200,
      average_view_duration_seconds: 150,
      video_length_seconds: 300,
      production_cost_usd: 50
    },
    %{
      id: "video-2",
      captured_at: "2026-06-08T00:00:00Z",
      views: 800,
      revenue_usd: 4.0,
      impressions: 8_000,
      clicks: 200,
      average_view_duration_seconds: 30,
      video_length_seconds: 180,
      production_cost_usd: 20
    }
  ]

  test "collects analytics metrics from latest snapshots" do
    assert {:ok, metrics} = AnalyticsGrowth.collect_metrics(@snapshots)
    assert metrics.total_videos == 2
    assert metrics.totals.views == 3_200
    assert_in_delta metrics.ctr, 1_400 / 28_000, 0.0001
    assert metrics.rpm > 0
  end

  test "predicts growth from historical deltas" do
    assert {:ok, prediction} = AnalyticsGrowth.growth_prediction(@snapshots, horizon_days: 7)
    assert prediction["video-1"].projected_views == 3_800
    assert prediction["video-1"].confidence == "medium"
  end

  test "generates report with retention, revenue, and chart data" do
    assert {:ok, report} = AnalyticsGrowth.report(@snapshots)
    assert report.analytics_data.total_videos == 2
    assert [%{id: "video-1"} | _] = report.retention_analysis
    assert is_list(report.revenue_optimization.recommendations)

    assert [%{label: "video-1", value: 2400} | _] =
             report.automated_report.chart_data.views_by_content
  end
end
