defmodule Lux.YouTube.LiveStreamingTest do
  use UnitCase, async: true

  alias Lux.YouTube.LiveStreaming

  describe "setup_automated_stream/1" do
    test "configures full live stream environment ready for encoder ingestion" do
      params = %{
        title: "24/7 Lux AI Agent Live Stream",
        description: "Live autonomous multi-agent simulation",
        resolution: :res_1080p,
        latency_preference: :ultra_low
      }

      {:ok, result} = LiveStreaming.setup_automated_stream(params)

      assert result.status == :ready_for_encoder
      assert is_binary(result.rtmp_url)
      assert is_binary(result.stream_key)
      assert is_binary(result.live_chat_id)
      assert result.initial_health.health_status == :good
    end
  end
end
