defmodule Lux.Integrations.YouTube.LiveStream do
  @moduledoc """
  Handles YouTube Live Stream creation, binding, and health monitoring.

  **NOTE**: Live streaming workflow transitions (e.g. ready -> testing -> 
  live -> complete) are exposed as basic endpoints but do not fully manage 
  state, retry logic, or credential-free test coverage.
  """

  alias Lux.Integrations.YouTube.Client

  @doc """
  Creates a new live broadcast.
  """
  def create_broadcast(params, config \\ Client.default_config()) do
    # Defaults for creating a broadcast
    query_params = [part: "snippet,status,contentDetails"]

    body = %{
      snippet: %{
        title: params[:title],
        description: params[:description] || "",
        scheduledStartTime: params[:scheduled_start_time]
      },
      status: %{
        privacyStatus: params[:privacy_status] || "private"
      },
      contentDetails: %{
        enableAutoStart: params[:enable_auto_start] || false,
        enableAutoStop: params[:enable_auto_stop] || false
      }
    }

    Client.post("/liveBroadcasts", body, query_params, config)
  end

  @doc """
  Creates a new live video stream (the actual video feed configuration).
  """
  def create_stream(params, config \\ Client.default_config()) do
    query_params = [part: "snippet,cdn,contentDetails"]

    body = %{
      snippet: %{
        title: params[:title]
      },
      cdn: %{
        frameRate: params[:frame_rate] || "30fps",
        ingestionType: "rtmp",
        resolution: params[:resolution] || "1080p"
      }
    }

    Client.post("/liveStreams", body, query_params, config)
  end

  @doc """
  Binds a broadcast to a stream.
  """
  def bind_broadcast(broadcast_id, stream_id, config \\ Client.default_config()) do
    query_params = [
      id: broadcast_id,
      streamId: stream_id,
      part: "id,contentDetails"
    ]

    Client.post("/liveBroadcasts/bind", %{}, query_params, config)
  end

  @doc """
  Transitions a broadcast's status (e.g. testing -> live).
  Allowed statuses: testing, live, complete.
  """
  def transition_broadcast(broadcast_id, broadcast_status, config \\ Client.default_config()) do
    query_params = [
      id: broadcast_id,
      broadcastStatus: broadcast_status,
      part: "id,status"
    ]

    Client.post("/liveBroadcasts/transition", %{}, query_params, config)
  end

  @doc """
  Retrieves a stream's health status.
  """
  def get_stream_health(stream_id, config \\ Client.default_config()) do
    query_params = [
      id: stream_id,
      part: "status"
    ]

    case Client.get("/liveStreams", query_params, config) do
      {:ok, %{"items" => [%{"status" => %{"healthStatus" => health}} | _]}} ->
        {:ok, health}

      {:ok, response} ->
        {:error, {:not_found, response}}

      error ->
        error
    end
  end
end
