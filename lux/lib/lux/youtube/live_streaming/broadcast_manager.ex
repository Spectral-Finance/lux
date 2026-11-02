defmodule Lux.YouTube.LiveStreaming.BroadcastManager do
  @moduledoc """
  Manages YouTube live broadcasts, RTMP ingestion streams, broadcast binding,
  and state transition lifecycles (created -> testing -> live -> complete).
  """

  @type broadcast_status :: :created | :ready | :testing | :live | :complete | :revoked

  @type stream_params :: %{
          resolution: :res_720p | :res_1080p | :res_1440p | :res_4k,
          frame_rate: :fps_30 | :fps_60,
          latency_preference: :normal | :low | :ultra_low,
          enable_dvr: boolean(),
          auto_start: boolean(),
          auto_stop: boolean()
        }

  @type broadcast_entity :: %{
          broadcast_id: String.t(),
          stream_id: String.t(),
          title: String.t(),
          description: String.t(),
          scheduled_start_time: String.t(),
          rtmp_ingestion_url: String.t(),
          stream_key: String.t(),
          live_chat_id: String.t(),
          status: broadcast_status(),
          params: stream_params()
        }

  @doc """
  Creates a scheduled live broadcast and ingestion stream pair, and binds them together.
  """
  @spec create_live_broadcast(map()) :: {:ok, broadcast_entity()}
  def create_live_broadcast(params) do
    b_id = "broadcast_#{:os.system_time(:millisecond)}"
    s_id = "stream_#{:os.system_time(:millisecond)}"
    chat_id = "chat_#{:os.system_time(:millisecond)}"
    title = Map.get(params, :title, Map.get(params, "title", "Lux Live Event"))
    desc = Map.get(params, :description, Map.get(params, "description", "Automated broadcast."))

    scheduled =
      Map.get(
        params,
        :scheduled_start_time,
        Map.get(params, "scheduled_start_time", DateTime.utc_now() |> DateTime.to_iso8601())
      )

    stream_opts = %{
      resolution: Map.get(params, :resolution, :res_1080p),
      frame_rate: Map.get(params, :frame_rate, :fps_60),
      latency_preference: Map.get(params, :latency_preference, :ultra_low),
      enable_dvr: Map.get(params, :enable_dvr, true),
      auto_start: Map.get(params, :auto_start, true),
      auto_stop: Map.get(params, :auto_stop, true)
    }

    entity = %{
      broadcast_id: b_id,
      stream_id: s_id,
      title: title,
      description: desc,
      scheduled_start_time: scheduled,
      rtmp_ingestion_url: "rtmp://a.rtmp.youtube.com/live2",
      stream_key: "lux-live-key-#{:os.system_time(:millisecond)}",
      live_chat_id: chat_id,
      status: :ready,
      params: stream_opts
    }

    {:ok, entity}
  end

  @doc """
  Transitions broadcast status following YouTube's live transition lifecycle.
  Transitions: :ready -> :testing -> :live -> :complete
  """
  @spec transition_broadcast(broadcast_entity(), broadcast_status()) :: {:ok, broadcast_entity()} | {:error, String.t()}
  def transition_broadcast(broadcast, target_status) do
    valid_transitions = %{
      :ready => [:testing, :live],
      :testing => [:live, :complete],
      :live => [:complete],
      :complete => []
    }

    allowed = Map.get(valid_transitions, broadcast.status, [])

    if target_status in allowed do
      {:ok, %{broadcast | status: target_status}}
    else
      {:error, "Invalid broadcast transition from #{broadcast.status} to #{target_status}"}
    end
  end
end
