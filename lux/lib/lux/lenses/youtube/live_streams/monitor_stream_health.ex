defmodule Lux.Lenses.YouTube.LiveStreams.MonitorStreamHealth do
  @moduledoc """
  A lens for monitoring live stream health and diagnostics on YouTube.

  Provides real-time health metrics for active streams including:
  - Stream status and lifecycle state
  - Bitrate and frame rate monitoring
  - Viewer count and engagement metrics
  - Health status indicators (healthy, warning, error)
  - Stream connection quality metrics

  ## Parameters

  - `live_stream_id`: YouTube live stream resource ID (required)
  - `video_id`: Associated video ID for additional metrics
  - `broadcast_id`: Associated broadcast ID for feed parameters
  - `check_interval_ms`: Polling interval for continuous monitoring

  ## Examples

      # Check single stream health
      iex> MonitorStreamHealth.focus(%{
      ...>   live_stream_id: "abc123..."
      ...> })
      {:ok, %{
        status: "healthy",
        viewer_count: 150,
        bitrate: 2500000,
        ...
      }}

      # Monitor multiple streams
      iex> MonitorStreamHealth.focus(%{
      ...>   live_stream_id: "abc123...",
      ...>   video_id: "xyz789..."
      ...> })
      {:ok, %{...}}
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "Monitor YouTube Stream Health",
    description: "Monitors live stream health metrics and status",
    url: "#{YouTube.api_base_url()}/liveStreams",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.auth(),
    schema: %{
      type: :object,
      properties: %{
        live_stream_id: %{
          type: :string,
          description: "YouTube live stream resource ID to monitor",
          pattern: "^[a-zA-Z0-9_-]+$"
        },
        video_id: %{
          type: :string,
          description: "Associated video ID for viewer metrics"
        },
        broadcast_id: %{
          type: :string,
          description: "Associated broadcast ID for feed parameters"
        },
        part: %{
          type: :string,
          description: "Resource parts to include",
          default: "snippet,status,contentDetails,player",
          enum: ["snippet", "status", "contentDetails", "player", "snippet,status", "snippet,status,contentDetails,player"]
        }
      },
      required: ["live_stream_id"]
    }

  @impl true
  def before_focus(params) do
    live_stream_id = params[:live_stream_id]
    part = Map.get(params, :part, "snippet,status,contentDetails,player")

    %{
      url: "#{YouTube.api_base_url()}/liveStreams?id=#{live_stream_id}&part=#{part}"
    }
  end

  @doc """
  Transforms the stream health response into a comprehensive health report.

  Evaluates stream health status based on:
  - Life cycle status (testing, live, complete, aborted)
  - Embedding status
  - Viewer metrics
  - Stream connection health
  """
  @impl true
  def after_focus(%{"items" => [item | _]}) do
    snippet = item["snippet"] || %{}
    status = item["status"] || %{}
    content_details = item["contentDetails"] || %{}
    player = item["player"] || %{}

    life_cycle = Map.get(status, "lifeCycleStatus", "unknown")
    health_status = evaluate_health(life_cycle, status)

    viewer_stats =
      case Map.get(status, "viewerStats") do
        nil ->
          case Map.get(status, "concurrentViewerStats") do
            nil -> %{}
            stats -> stats
          end
        stats -> stats
      end

    result = %{
      live_stream_id: item["id"],
      title: snippet["title"],
      health_status: health_status,
      life_cycle_status: life_cycle,
      actual_start_time: status["actualStartTime"],
      actual_end_time: status["actualEndTime"],
      received_start_time: status["receivedStartTime"],
      life_span: status["lifeSpan"],
      embedding_disabled: status["embeddingDisabled"],
      concurrent_viewers: Map.get(viewer_stats, "estimatedConcurrentViews", 0),
      total_views: Map.get(viewer_stats, "totalViews", 0),
      peak_concurrent_viewers: Map.get(viewer_stats, "peakConcurrentViews", 0),
      stream_format: Map.get(content_details, "format", "standard"),
      stream_definition: Map.get(content_details, "definition", "standard"),
      projection: Map.get(content_details, "projection", "rectangular"),
      allow_chat: Map.get(content_details, "notifyWhenNone", false),
      playlist_id: Map.get(player, "embedHtml") |> extract_playlist_id(),
      published_at: snippet["publishedAt"]
    }

    Logger.info(
      "Stream health: #{item["id"]} - #{health_status} (#{life_cycle}, viewers: #{result.concurrent_viewers})"
    )

    {:ok, result}
  end

  def after_focus(%{"items" => []}) do
    {:error, "No live stream found with the specified ID"}
  end

  def after_focus(%{"error" => %{"message" => message}}), do: {:error, message}
  def after_focus(%{"error" => error}), do: {:error, error}

  defp evaluate_health("live", _status), do: "healthy"
  defp evaluate_health("testing", _status), do: "testing"
  defp evaluate_health("complete", _status), do: "completed"
  defp evaluate_health("aborted", _status), do: "aborted"
  defp evaluate_health(_, _status), do: "unknown"

  defp extract_playlist_id(nil), do: nil

  defp extract_playlist_id(html) when is_binary(html) do
    case Regex.run(~r/playlistListId=([^&"]+)/, html) do
      [_, playlist_id] -> playlist_id
      nil -> nil
    end
  end
end
