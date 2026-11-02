defmodule Lux.YouTube.ContentIntelligence.PerformanceAnalyticsTest do
  use UnitCase, async: true

  alias Lux.YouTube.ContentIntelligence.PerformanceAnalytics

  describe "evaluate_performance/2" do
    test "correctly calculates video velocity, retention, and engagement rates" do
      video_stats = %{
        views: 10_000,
        watch_time_seconds: 3_000_000.0,
        duration_seconds: 600.0,
        published_hours_ago: 20.0,
        likes: 650,
        comments: 120,
        shares: 80,
        retention_curve: [
          %{timestamp_seconds: 0, percentage_retained: 100.0},
          %{timestamp_seconds: 30, percentage_retained: 74.0},
          %{timestamp_seconds: 300, percentage_retained: 58.0},
          %{timestamp_seconds: 600, percentage_retained: 46.0}
        ]
      }

      channel_baseline = %{avg_views_at_24h: 5_000.0}

      summary = PerformanceAnalytics.evaluate_performance(video_stats, channel_baseline)

      assert summary.views == 10_000
      assert summary.watch_time_minutes == 50_000.0
      assert summary.average_view_duration_seconds == 300.0
      assert summary.average_percentage_viewed == 50.0
      assert summary.views_per_hour == 500.0
      assert summary.benchmark_multiplier == 2.0
      assert summary.hook_retention_rate == 74.0
      assert summary.retention_health == :good
      assert summary.velocity_score > 80.0
    end

    test "handles zero views gracefully" do
      video_stats = %{views: 0, duration_seconds: 300.0}
      summary = PerformanceAnalytics.evaluate_performance(video_stats)

      assert summary.views == 0
      assert summary.average_percentage_viewed == 0.0
      assert summary.retention_health == :poor
    end
  end

  describe "analyze_retention_curve/1" do
    test "detects major drop-off points" do
      curve = [
        %{timestamp_seconds: 0, percentage_retained: 100.0},
        %{timestamp_seconds: 30, percentage_retained: 85.0},
        %{timestamp_seconds: 60, percentage_retained: 68.0}, # drop of 17%
        %{timestamp_seconds: 120, percentage_retained: 62.0},
        %{timestamp_seconds: 300, percentage_retained: 45.0}  # drop of 17%
      ]

      result = PerformanceAnalytics.analyze_retention_curve(curve)

      assert result.hook_rate == 85.0
      assert 60 in result.major_drop_points
      assert 300 in result.major_drop_points
    end

    test "handles empty curve safely" do
      result = PerformanceAnalytics.analyze_retention_curve([])
      assert result.hook_rate == 0.0
      assert result.major_drop_points == []
    end
  end
end
