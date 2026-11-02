defmodule Lux.YouTube.ContentIntelligenceTest do
  use UnitCase, async: true

  alias Lux.YouTube.ContentIntelligence

  describe "audit_video/2" do
    test "executes end-to-end audit compiling performance, audience, and CTR recommendations" do
      video_data = %{
        title: "How to Build Autonomous AI Agents in Elixir [Full Guide]",
        stats: %{
          views: 15_000,
          watch_time_seconds: 4_500_000.0,
          duration_seconds: 600.0,
          published_hours_ago: 24.0,
          likes: 900,
          comments: 180,
          shares: 95,
          retention_curve: [
            %{timestamp_seconds: 0, percentage_retained: 100.0},
            %{timestamp_seconds: 30, percentage_retained: 72.0},
            %{timestamp_seconds: 600, percentage_retained: 45.0}
          ]
        },
        audience: %{
          returning_viewers: 6_000,
          sub_watch_time_pct: 45.0
        },
        thumbnail: %{
          overlay_text_word_count: 3,
          contrast_ratio: 5.5,
          has_human_face: true
        }
      }

      audit = ContentIntelligence.audit_video(video_data)

      assert audit.title == "How to Build Autonomous AI Agents in Elixir [Full Guide]"
      assert audit.overall_health_score >= 70.0
      assert audit.verdict in [:high_performer, :stable_grower]
      assert audit.performance.views == 15_000
      assert audit.audience_profile.loyalty_score > 0
      assert audit.title_evaluation.ctr_potential_score > 70.0
      assert is_list(audit.actionable_recommendations)
    end
  end
end
