defmodule Lux.YouTube.LiveStreaming.HealthMonitor do
  @moduledoc """
  Monitors RTMP ingestion stream health, bitrate stability, frame rate consistency,
  and raises automated health alerts for YouTube live broadcasts.
  """

  @type health_verdict :: :good | :ok | :bad | :no_data

  @type stream_health_report :: %{
          stream_id: String.t(),
          health_status: health_verdict(),
          current_bitrate_kbps: non_neg_integer(),
          current_fps: float(),
          target_bitrate_kbps: non_neg_integer(),
          audio_healthy: boolean(),
          issues_detected: list(String.t()),
          is_stream_stable: boolean()
        }

  @doc """
  Evaluates raw ingestion stream metrics and returns diagnostic health report.
  """
  @spec evaluate_health(String.t(), map()) :: stream_health_report()
  def evaluate_health(stream_id, telemetry) when is_map(telemetry) do
    bitrate = Map.get(telemetry, :bitrate_kbps, Map.get(telemetry, "bitrate_kbps", 6000))
    fps = Map.get(telemetry, :fps, Map.get(telemetry, "fps", 60.0))
    target_bitrate = Map.get(telemetry, :target_bitrate_kbps, 6000)
    audio_healthy = Map.get(telemetry, :audio_healthy, true)

    issues = []

    {issues, health_status} =
      cond do
        bitrate == 0 ->
          {["No data received from encoder. Check RTMP feed." | issues], :no_data}

        bitrate < (target_bitrate * 0.60) or fps < 45.0 ->
          {["Significant bitrate or frame rate drop detected." | issues], :bad}

        bitrate < (target_bitrate * 0.85) or fps < 55.0 ->
          {["Sub-optimal ingestion bandwidth detected." | issues], :ok}

        true ->
          {issues, :good}
      end

    {issues, health_status} =
      if not audio_healthy do
        {["Audio track missing or corrupted in RTMP stream." | issues], :bad}
      else
        {issues, health_status}
      end

    %{
      stream_id: stream_id,
      health_status: health_status,
      current_bitrate_kbps: bitrate,
      current_fps: fps,
      target_bitrate_kbps: target_bitrate,
      audio_healthy: audio_healthy,
      issues_detected: Enum.reverse(issues),
      is_stream_stable: health_status in [:good, :ok]
    }
  end
end
