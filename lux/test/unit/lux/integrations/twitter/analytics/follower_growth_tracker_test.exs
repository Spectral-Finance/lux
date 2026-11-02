defmodule Lux.Integrations.Twitter.Analytics.FollowerGrowthTrackerTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Twitter.Analytics.FollowerGrowthTracker

  describe "analyze_growth/1" do
    test "calculates net growth and percentage between snapshots" do
      snapshots = [
        %{
          timestamp: "2026-11-01T00:00:00Z",
          followers_count: 10_000,
          following_count: 500,
          tweet_count: 1200
        },
        %{
          timestamp: "2026-11-02T00:00:00Z",
          followers_count: 10_500,
          following_count: 500,
          tweet_count: 1210
        }
      ]

      result = FollowerGrowthTracker.analyze_growth(snapshots)

      assert result.current_followers == 10_500
      assert result.net_follower_change == 500
      # 500 / 10000 * 100 = 5.0%
      assert result.growth_rate_percent == 5.0
      # 10500 / 500 = 21.0
      assert result.follower_to_following_ratio == 21.0
      # 500 in 1 day = 500 / day
      assert result.daily_run_rate == 500.0
      assert result.snapshot_count == 2
    end

    test "handles single snapshot gracefully" do
      snapshot = [%{followers_count: 1000, following_count: 100}]
      result = FollowerGrowthTracker.analyze_growth(snapshot)

      assert result.current_followers == 1000
      assert result.net_follower_change == 0
      assert result.follower_to_following_ratio == 10.0
    end

    test "handles empty snapshot list" do
      result = FollowerGrowthTracker.analyze_growth([])
      assert result.current_followers == 0
      assert result.net_follower_change == 0
    end
  end
end
