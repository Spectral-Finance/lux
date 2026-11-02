defmodule Lux.YouTube.GrowthEngine.MetricsTrackerTest do
  use UnitCase, async: true

  alias Lux.YouTube.GrowthEngine.MetricsTracker

  describe "track_window/1" do
    test "correctly calculates watch time hours, RPM, conversion rate, and momentum score" do
      raw_data = %{
        views: 50_000,
        watch_time_seconds: 18_000_000.0, # 5,000 hours
        subscribers_gained: 850,
        subscribers_lost: 50,
        impressions: 500_000,
        clicks: 25_000,
        estimated_revenue_usd: 300.0,
        playback_cpm: 12.0
      }

      window = MetricsTracker.track_window(raw_data)

      assert window.views == 50_000
      assert window.watch_time_hours == 5_000.0
      assert window.net_subscribers == 800
      assert window.click_through_rate == 5.0
      assert window.estimated_revenue_usd == 300.0
      assert window.rpm == 6.0
      assert window.conversion_rate_per_10k_views == 160.0
      assert window.momentum_score > 50.0
    end

    test "handles zero views safely" do
      window = MetricsTracker.track_window(%{views: 0})

      assert window.views == 0
      assert window.rpm == 0.0
      assert window.click_through_rate == 0.0
    end
  end
end
