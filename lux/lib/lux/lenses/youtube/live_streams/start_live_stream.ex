defmodule Lux.Lenses.YouTube.LiveStreams.StartLiveStream do
  @moduledoc """
  A lens for transitioning a live stream from testing to live status.

  Manages stream lifecycle transitions:
  - Testing -> Live: Makes the stream publicly visible
  - Live -> Complete: Ends the stream gracefully
  - Restart: Restarts a paused stream

  ## Parameters

  - `live_stream_id`: YouTube live stream resource ID (required)
  - `action`: Action to perform (start, pause, complete, restart)
  - `video_id`: Associated video ID (required for streaming uploads)
  - `broadcast_id`: Associated broadcast ID (required for managing broadcast settings)

  ## Examples

      # Start a testing stream as live
      iex> StartLiveStream.focus(%{
      ...>   live_stream_id: "abc123...",
      ...>   action: "start",
      ...>   video_id: "xyz789..."
      ...> })
      {:ok, %{status: "live", live_stream_id: "abc123..."}}

      # End a live stream gracefully
      iex> StartLiveStream.focus(%{
      ...>   live_stream_id: "abc123...",
      ...>   action: "complete",
      ...>   video_id: "xyz789..."
      ...> })
      {:ok, %{status: "completed", live_stream_id: "abc123..."}}
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "Start YouTube Live Stream",
    description: "Transitions a live stream between testing, live, and complete states",
    url: "#{YouTube.api_base_url()}/liveStreams",
    method: :patch,
    headers: YouTube.headers(),
    auth: YouTube.auth(),
    schema: %{
      type: :object,
      properties: %{
        live_stream_id: %{
          type: :string,
          description: "YouTube live stream resource ID",
          pattern: "^[a-zA-Z0-9_-]+$"
        },
        action: %{
          type: :string,
          description: "Action to perform on the stream",
          enum: ["start", "pause", "complete", "restart"],
          default: "start"
        },
        video_id: %{
          type: :string,
          description: "Associated video ID for streaming uploads",
          pattern: "^[a-zA-Z0-9_-]{11}$"
        },
        broadcast_id: %{
          type: :string,
          description: "Associated broadcast ID for managing broadcast settings"
        },
        title: %{
          type: :string,
          description: "New stream title (for transitions)"
        },
        description: %{
          type: :string,
          description: "New stream description"
        }
      },
      required: ["live_stream_id", "action"]
    }

  @impl true
  def before_focus(params) do
    live_stream_id = params[:live_stream_id]
    action = Map.get(params, :action, "start")

    body = build_body(params, action)

    %{
      url: "#{YouTube.api_base_url()}/liveStreams?id=#{live_stream_id}&part=snippet,contentDetails,status",
      json: body
    }
  end

  @doc """
  Transforms the live stream transition response.
  """
  @impl true
  def after_focus(%{
    "id" => stream_id,
    "snippet" => snippet,
    "status" => status
  }) do
    Logger.info("Successfully transitioned live stream #{stream_id} to #{status["lifeCycleStatus"]}")

    {:ok, %{
      id: stream_id,
      title: snippet["title"],
      life_cycle_status: status["lifeCycleStatus"],
      embedding_disabled: status["embeddingDisabled"],
      life_span: status["lifeSpan"],
      received_start_time: status["receivedStartTime"],
      actual_start_time: status["actualStartTime"],
      actual_end_time: status["actualEndTime"]
    }}
  end

  def after_focus(%{"error" => %{"message" => message}}), do: {:error, message}
  def after_focus(%{"error" => error}), do: {:error, error}

  defp build_body(params, action) do
    snippet =
      case action do
        "start" ->
          %{
            title: Map.get(params, :title),
            description: Map.get(params, :description)
          }

        "complete" ->
          %{}

        _ ->
          %{
            title: Map.get(params, :title),
            description: Map.get(params, :description)
          }
      end

    content_details =
      case action do
        "start" ->
          %{
            manifestName: "live-stream-#{params[:live_stream_id]}"
          }

        "complete" ->
          %{}

        _ ->
          %{}
      end

    %{
      snippet: snippet,
      contentDetails: content_details
    }
  end
end
