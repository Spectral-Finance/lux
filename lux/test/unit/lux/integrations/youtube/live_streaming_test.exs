defmodule Lux.Integrations.YouTube.LiveStreamingTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.YouTube.LiveStreaming

  describe "plan_broadcast_workflow/1" do
    test "returns a credential-free YouTube live workflow plan" do
      assert {:ok, workflow} =
               LiveStreaming.plan_broadcast_workflow(%{
                 "title" => "Lux market briefing",
                 "scheduled_start_time" => "2026-06-06T12:00:00Z",
                 "privacy_status" => "unlisted",
                 "broadcast_id" => "broadcast-1",
                 "stream_id" => "stream-1",
                 "live_chat_id" => "chat-1",
                 "live_chat_page_token" => "page-2",
                 "video_id" => "video-1",
                 "upload_url" => "https://upload.youtube.test/session",
                 "content_length" => 256,
                 "total_length" => 1024,
                 "chat_messages" => [
                   %{"id" => "m1", "author" => "viewer", "text" => "great stream"},
                   %{"id" => "m2", "author" => "spammer", "text" => "click https://bad.test"}
                 ]
               })

      assert workflow.mode == :dry_run
      assert workflow.broadcast.insert.method == :post
      assert workflow.broadcast.insert.url =~ "/liveBroadcasts"
      assert workflow.stream.insert.url =~ "/liveStreams"
      assert workflow.bind.query == %{"id" => "broadcast-1", "streamId" => "stream-1", "part" => "id,contentDetails"}
      assert workflow.upload.status_request.query["id"] == "video-1"
      assert workflow.upload.upload_session.required_parameter == :upload_url
      assert {"Content-Range", "bytes 0-255/1024"} in workflow.upload.chunk_upload.headers
      assert {"Content-Range", "bytes */1024"} in workflow.upload.resume_probe.headers
      assert workflow.live_chat.list.query["pageToken"] == "page-2"
      assert workflow.live_chat.pagination.next_page_token == :from_youtube_response
      assert workflow.live_chat.pagination.polling_interval_millis == :from_youtube_response
      assert workflow.live_chat.moderation.requires_review == true
      assert workflow.execution_boundary.live_side_effects == false
    end

    test "validates required scheduling fields" do
      assert {:error, "Missing required YouTube live parameter title"} =
               LiveStreaming.plan_broadcast_workflow(%{
                 scheduled_start_time: "2026-06-06T12:00:00Z"
               })
    end

    test "guards dependent requests when YouTube resource ids are not available yet" do
      assert {:ok, workflow} =
               LiveStreaming.plan_broadcast_workflow(%{
                 title: "Lux market briefing",
                 scheduled_start_time: "2026-06-06T12:00:00Z"
               })

      assert workflow.bind.executable == false
      assert workflow.bind.required_parameters == [:broadcast_id, :stream_id]
      assert workflow.stream.status.executable == false
      assert workflow.stream.status.required_parameters == [:stream_id]
      assert workflow.health_monitor.request.executable == false
      assert workflow.health_monitor.request.required_parameters == [:stream_id]
      assert workflow.transition.request.executable == false
      assert workflow.transition.request.required_parameters == [:broadcast_id]
      assert workflow.live_chat.list.executable == false
      assert workflow.live_chat.send.executable == false
      assert workflow.upload.status_request.required_parameters == [:video_id]
      assert workflow.upload.chunk_upload.required_parameters == [:upload_url, :content_length]
      assert workflow.upload.resume_probe.required_parameters == [:upload_url, :total_length]
    end

    test "omits optional nil fields from broadcast insert json" do
      assert {:ok, workflow} =
               LiveStreaming.plan_broadcast_workflow(%{
                 title: "Lux market briefing",
                 scheduled_start_time: "2026-06-06T12:00:00Z"
               })

      refute Map.has_key?(workflow.broadcast.insert.json.snippet, :scheduledEndTime)
    end
  end

  describe "health_snapshot/1" do
    test "flags low bitrate, dropped frames, and latency" do
      snapshot =
        LiveStreaming.health_snapshot(%{
          status: "good",
          bitrate_kbps: 1_200,
          min_bitrate_kbps: 2_500,
          dropped_frames: 45,
          max_dropped_frames: 30,
          latency_ms: 12_000,
          max_latency_ms: 10_000
        })

      assert snapshot.status == :attention_required
      assert "low_bitrate" in snapshot.issues
      assert "dropped_frames" in snapshot.issues
      assert "high_latency" in snapshot.issues
    end
  end

  describe "transition_plan/1" do
    test "allows testing to live transition and rejects invalid transitions" do
      allowed =
        LiveStreaming.transition_plan(%{
          broadcast_id: "broadcast-1",
          current_life_cycle_status: "testing",
          target_life_cycle_status: "live"
        })

      assert allowed.allowed == true
      assert allowed.request.query["broadcastStatus"] == "live"

      rejected =
        LiveStreaming.transition_plan(%{
          broadcast_id: "broadcast-1",
          current_life_cycle_status: "complete",
          target_life_cycle_status: "live"
        })

      assert rejected.allowed == false
      assert rejected.guardrails == ["completed broadcasts cannot be transitioned again"]
    end

    test "does not build transition requests without a broadcast id" do
      guarded =
        LiveStreaming.transition_plan(%{
          current_life_cycle_status: "testing",
          target_life_cycle_status: "live"
        })

      assert guarded.allowed == false
      assert guarded.request.executable == false
      assert guarded.request.required_parameters == [:broadcast_id]
      assert "Missing required YouTube live parameter broadcast_id" in guarded.guardrails
    end
  end
end
