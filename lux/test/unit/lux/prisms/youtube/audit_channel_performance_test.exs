defmodule Lux.Prisms.YouTube.AuditChannelPerformanceTest do
  @moduledoc """
  Test suite for the YouTube AuditChannelPerformance prism.
  Verifies:
  - Full audit with recent video data
  - High-performing channel returns strengths and high score
  - Low-performing channel returns weaknesses and action items
  - Minimal params (no recent videos)
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.YouTube.AuditChannelPerformance

  @agent_ctx %{agent: %{name: "TestAgent"}}

  describe "handler/2" do
    test "returns high audit score for a well-performing channel" do
      assert {:ok, result} = AuditChannelPerformance.handler(
        %{
          "subscriber_count" => 500_000,
          "view_count" => 40_000_000,
          "video_count" => 350,
          "recent_videos" => [
            %{"view_count" => 80_000, "like_count" => 5_000, "comment_count" => 400},
            %{"view_count" => 120_000, "like_count" => 7_500, "comment_count" => 600},
            %{"view_count" => 95_000, "like_count" => 6_200, "comment_count" => 480}
          ]
        },
        @agent_ctx
      )

      assert result.audit_score >= 60
      assert "upload_consistency" in result.strengths or "engagement" in result.strengths
      assert is_list(result.action_items)
    end

    test "returns low audit score with weaknesses for a new channel" do
      assert {:ok, result} = AuditChannelPerformance.handler(
        %{
          "subscriber_count" => 50,
          "view_count" => 1_200,
          "video_count" => 3,
          "recent_videos" => [
            %{"view_count" => 200, "like_count" => 5, "comment_count" => 1}
          ]
        },
        @agent_ctx
      )

      assert result.audit_score < 40
      assert length(result.weaknesses) >= 1
      assert length(result.action_items) >= 1
    end

    test "handles missing recent_videos gracefully" do
      assert {:ok, result} = AuditChannelPerformance.handler(
        %{
          "subscriber_count" => 10_000,
          "view_count" => 800_000,
          "video_count" => 80
        },
        @agent_ctx
      )

      assert is_integer(result.audit_score)
      assert result.audit_score >= 0 and result.audit_score <= 100
      assert is_list(result.strengths)
      assert is_list(result.weaknesses)
      assert is_list(result.action_items)
    end

    test "audit score never exceeds 100" do
      assert {:ok, result} = AuditChannelPerformance.handler(
        %{
          "subscriber_count" => 5_000_000,
          "view_count" => 500_000_000,
          "video_count" => 1_000,
          "recent_videos" => [
            %{"view_count" => 1_000_000, "like_count" => 80_000, "comment_count" => 5_000}
          ]
        },
        @agent_ctx
      )

      assert result.audit_score <= 100
    end
  end
end
