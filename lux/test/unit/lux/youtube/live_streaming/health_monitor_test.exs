defmodule Lux.YouTube.LiveStreaming.HealthMonitorTest do
  use UnitCase, async: true

  alias Lux.YouTube.LiveStreaming.HealthMonitor

  describe "evaluate_health/2" do
    test "scores healthy 1080p60 stream as good" do
      telemetry = %{
        bitrate_kbps: 6200,
        fps: 60.0,
        target_bitrate_kbps: 6000,
        audio_healthy: true
      }

      report = HealthMonitor.evaluate_health("stream_123", telemetry)

      assert report.health_status == :good
      assert report.is_stream_stable == true
      assert report.issues_detected == []
    end

    test "detects bitrate degradation and audio issues" do
      telemetry = %{
        bitrate_kbps: 2100,
        fps: 35.0,
        target_bitrate_kbps: 6000,
        audio_healthy: false
      }

      report = HealthMonitor.evaluate_health("stream_123", telemetry)

      assert report.health_status == :bad
      assert report.is_stream_stable == false
      assert length(report.issues_detected) >= 2
    end
  end
end
