defmodule Lux.Beams.Twitter.MonitoringBeamTest do
  use ExUnit.Case, async: true

  alias Lux.Beams.Twitter.MonitoringBeam

  describe "run/2" do
    test "orchestrates full monitoring workflow" do
      tweets = [
        %{
          "id" => "campaign_1",
          "text" => "Launching the #Lux agent economy! #Web3",
          "public_metrics" => %{"like_count" => 600, "retweet_count" => 150, "impression_count" => 10_000}
        }
      ]

      mentions = [
        "Incredible tech, love the new prisms! 🚀",
        "Looking forward to building on Lux."
      ]

      snapshots = [
        %{followers_count: 5000, following_count: 200, timestamp: "2026-11-01T00:00:00Z"},
        %{followers_count: 5200, following_count: 200, timestamp: "2026-11-02T00:00:00Z"}
      ]

      {:ok, result} =
        MonitoringBeam.run(%{
          tweets: tweets,
          mentions: mentions,
          snapshots: snapshots,
          handle: "@Spectral_Fi",
          thresholds: %{like_threshold: 500}
        })

      assert result.metrics.likes == 600
      assert result.growth.net_follower_change == 200
      assert result.sentiment.positive_percentage == 50.0
      assert result.alert_count == 1
      assert String.contains?(result.report, "# 📊 Twitter Performance & Monitoring Report: @Spectral_Fi")
    end
  end
end
