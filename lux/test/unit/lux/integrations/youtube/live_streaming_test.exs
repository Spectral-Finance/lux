defmodule Lux.Integrations.YouTube.LiveStreamingTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.YouTube.LiveStreaming

  @broadcast %{
    "id" => "broadcast-1",
    "status" => %{"lifeCycleStatus" => "ready"},
    "snippet" => %{"liveChatId" => "chat-1"}
  }

  @stream %{
    "id" => "stream-1",
    "snippet" => %{"title" => "Primary Stream"},
    "cdn" => %{"resolution" => "1080p", "frameRate" => "60fps"},
    "status" => %{
      "streamStatus" => "active",
      "healthStatus" => %{"status" => "good", "configurationIssues" => []}
    }
  }

  describe "request bodies" do
    test "builds broadcast, stream, and chat bodies" do
      broadcast =
        LiveStreaming.broadcast_body(%{
          title: "Launch",
          scheduled_start_time: "2026-05-13T13:00:00Z",
          privacy_status: "unlisted"
        })

      assert broadcast.snippet.title == "Launch"
      assert broadcast.status.privacyStatus == "unlisted"
      assert broadcast.contentDetails.monitorStream.enableMonitorStream == true

      stream =
        LiveStreaming.stream_body(%{title: "Primary", resolution: "1080p", frame_rate: "60fps"})

      assert stream.cdn.ingestionType == "rtmp"
      assert stream.cdn.resolution == "1080p"

      chat = LiveStreaming.chat_message_body("chat-1", "hello")
      assert chat.snippet.type == "textMessageEvent"
      assert chat.snippet.textMessageDetails.messageText == "hello"
    end
  end

  describe "health and transitions" do
    test "approves live transition when stream is active and healthy" do
      health = LiveStreaming.stream_health(@broadcast, @stream)
      assert health.ready_for_live == true

      assert {:ok, plan} = LiveStreaming.transition_plan(@broadcast, @stream, "live")
      assert plan.decision == :approved
    end

    test "blocks live transition when stream is inactive" do
      inactive_stream = put_in(@stream, ["status", "streamStatus"], "inactive")

      assert {:error, plan} = LiveStreaming.transition_plan(@broadcast, inactive_stream, "live")
      assert plan.decision == :blocked
      assert "stream must be active before testing or live transition" in plan.alerts
    end

    test "evaluates quality control for multiple streams" do
      bad_stream =
        @stream
        |> put_in(["id"], "stream-2")
        |> put_in(["cdn", "resolution"], "480p")

      quality = LiveStreaming.quality_control([@stream, bad_stream])

      assert quality.status == :attention_required
      assert [%{status: :ready}, %{status: :attention_required}] = quality.streams
    end
  end

  describe "chat and dashboard" do
    test "normalizes chat messages and builds dashboard" do
      payload = %{
        "items" => [
          %{
            "id" => "msg-1",
            "snippet" => %{
              "displayMessage" => "hello",
              "type" => "textMessageEvent",
              "publishedAt" => "2026-05-13T13:01:00Z"
            },
            "authorDetails" => %{"displayName" => "Viewer"}
          }
        ]
      }

      assert [%{author: "Viewer", message: "hello"}] = LiveStreaming.chat_messages(payload)

      dashboard =
        LiveStreaming.dashboard(%{
          broadcast: @broadcast,
          stream: @stream,
          chat_messages: payload
        })

      assert dashboard.health.ready_for_live == true
      assert dashboard.quality.status == :ready
      assert [%{id: "msg-1"}] = dashboard.chat
    end
  end
end
