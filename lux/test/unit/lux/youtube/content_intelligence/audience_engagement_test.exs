defmodule Lux.YouTube.ContentIntelligence.AudienceEngagementTest do
  use UnitCase, async: true

  alias Lux.YouTube.ContentIntelligence.AudienceEngagement

  describe "analyze_audience/1" do
    test "evaluates returning viewers, loyalty score, and engagement grade" do
      data = %{
        views: 20_000,
        likes: 1_200,
        comments: 250,
        shares: 180,
        returning_viewers: 9_000,
        sub_watch_time_pct: 42.0,
        traffic_sources: %{
          "suggested" => 55.0,
          "browse" => 30.0,
          "search" => 10.0,
          "external" => 5.0
        }
      }

      profile = AudienceEngagement.analyze_audience(data)

      assert profile.returning_viewer_ratio == 0.45
      assert profile.subscriber_watch_ratio == 42.0
      assert profile.like_ratio == 6.0
      assert profile.comment_density_per_1k == 12.5
      assert profile.primary_traffic_source == "suggested"
      assert profile.traffic_source_health == :suggested_viral
      assert profile.loyalty_score >= 50.0
      assert profile.engagement_grade in [:s, :a]
    end

    test "handles low engagement video with grade c or f" do
      data = %{
        views: 5_000,
        likes: 20,
        comments: 2,
        shares: 0,
        returning_viewers: 200,
        sub_watch_time_pct: 10.0
      }

      profile = AudienceEngagement.analyze_audience(data)

      assert profile.like_ratio == 0.4
      assert profile.engagement_grade == :f
    end
  end
end
