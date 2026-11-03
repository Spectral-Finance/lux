defmodule Lux.Integrations.YouTube.ContentIntelligenceTest do
  use ExUnit.Case, async: true
  alias Lux.Integrations.YouTube.ContentIntelligence

  test "computes engagement rate, retention percentage, and composite score" do
    assert {:ok, res} =
             ContentIntelligence.score_video_performance(%{
               views: 10_000,
               likes: 600,
               comments: 100,
               avg_view_duration_sec: 360,
               duration_sec: 600
             })

    assert res.engagement_rate_pct == 8.0
    assert res.retention_pct == 60.0
    assert res.composite_score == 39.2
  end
end
