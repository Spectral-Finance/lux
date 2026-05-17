defmodule Lux.Integrations.YouTube.AnalyticsGrowthTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.YouTube.AnalyticsGrowth

  describe "snapshot/1" do
    test "calculates engagement, conversion, retention, and ROI metrics" do
      metrics = %{
        views: 1_000,
        likes: 50,
        comments: 20,
        shares: 10,
        subscribers: 25,
        revenue: 250,
        cost: 100,
        average_view_duration_seconds: 180,
        video_duration_seconds: 300
      }

      assert AnalyticsGrowth.snapshot(metrics) == %{
               views: 1000.0,
               watch_time_minutes: 0.0,
               subscribers: 25.0,
               engagement_rate: 0.08,
               subscriber_conversion_rate: 0.025,
               revenue: 250.0,
               cost: 100.0,
               roi: 1.5,
               retention_rate: 0.6
             }
    end
  end

  describe "growth_trend/1" do
    test "returns view, subscriber, and revenue growth across snapshots" do
      trend =
        AnalyticsGrowth.growth_trend([
          %{views: 1_000, subscribers: 100, revenue: 50},
          %{views: 1_500, subscribers: 130, revenue: 75}
        ])

      assert trend.view_growth_rate == 0.5
      assert trend.subscriber_growth_rate == 0.3
      assert trend.revenue_growth_rate == 0.5
      assert length(trend.points) == 2
    end
  end

  describe "benchmark/2" do
    test "compares channel metrics with competitor averages" do
      benchmark =
        AnalyticsGrowth.benchmark(
          %{
            views: 2_000,
            likes: 100,
            comments: 50,
            shares: 50,
            average_view_duration_seconds: 240,
            video_duration_seconds: 300
          },
          [
            %{
              views: 1_000,
              likes: 20,
              comments: 10,
              shares: 10,
              average_view_duration_seconds: 120,
              video_duration_seconds: 300
            },
            %{
              views: 3_000,
              likes: 60,
              comments: 30,
              shares: 30,
              average_view_duration_seconds: 150,
              video_duration_seconds: 300
            }
          ]
        )

      assert benchmark.competitor_average.views == 2000.0
      assert benchmark.relative_view_performance == 1.0
      assert benchmark.relative_engagement_performance > 1.0
      assert benchmark.relative_retention_performance > 1.0
    end
  end

  describe "audit/2" do
    test "returns failed checks with actionable recommendations" do
      audit =
        AnalyticsGrowth.audit(%{
          views: 1_000,
          likes: 5,
          comments: 2,
          shares: 1,
          subscribers: 2,
          revenue: 80,
          cost: 100,
          average_view_duration_seconds: 60,
          video_duration_seconds: 300
        })

      failed_names = Enum.map(audit.failed, & &1.name)

      assert :engagement in failed_names
      assert :retention in failed_names
      assert :subscriber_conversion in failed_names
      assert :roi in failed_names
      assert audit.passed == 0
    end
  end

  describe "report/3" do
    test "builds an automated report payload for Lux agents" do
      report =
        AnalyticsGrowth.report(
          [
            %{views: 1_000, subscribers: 100, revenue: 100, cost: 50},
            %{
              views: 1_400,
              subscribers: 120,
              revenue: 160,
              cost: 80,
              average_view_duration_seconds: 200,
              video_duration_seconds: 300
            }
          ],
          [%{views: 1_000, likes: 10, comments: 5, shares: 5}],
          generated_at: ~U[2026-05-13 00:00:00Z]
        )

      assert report.generated_at == ~U[2026-05-13 00:00:00Z]
      assert report.summary.view_growth_rate == 0.4
      assert is_map(report.trend)
      assert [%{period: 1, projected_views: 1800.0}] = Enum.take(report.forecast, 1)
      assert report.revenue_optimization.current_rpm > 0
      assert is_map(report.audit)
      assert is_map(report.benchmark)
      assert is_list(report.recommendations)
    end
  end
end
