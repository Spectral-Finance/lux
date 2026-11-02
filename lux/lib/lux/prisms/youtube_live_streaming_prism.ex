defmodule Lux.Prisms.YouTubeLiveStreamingPrism do
  @moduledoc """
  A Prism for autonomous agents to manage YouTube platform operations,
  video uploads, live broadcasts, stream health monitoring, and live chat engagement.

  ## Examples

      iex> Lux.Prisms.YouTubeLiveStreamingPrism.run(%{
      ...>   action: "create_broadcast",
      ...>   payload: %{title: "Lux 24/7 Agent Swarm Live"}
      ...> })
      {:ok, %{action: "create_broadcast", result: %{broadcast_id: "...", rtmp_ingestion_url: "..."}}}
  """

  use Lux.Prism,
    name: "YouTube Live Streaming Prism",
    description: "Controls YouTube Data API v3 live streaming, resumable video uploads, stream health telemetry, and live chat interaction",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: [
            "get_auth_url",
            "initiate_upload",
            "upload_chunk",
            "create_broadcast",
            "transition_broadcast",
            "check_stream_health",
            "process_chat",
            "respond_to_chat",
            "setup_automated_stream"
          ],
          description: "Live streaming or YouTube Data API action to execute"
        },
        payload: %{
          type: :object,
          description: "Payload data corresponding to chosen action"
        }
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string},
        result: %{type: :object}
      },
      required: ["action", "result"]
    }

  alias Lux.YouTube.LiveStreaming

  def handler(input, _context) do
    action = Map.get(input, :action) || Map.get(input, "action", "setup_automated_stream")
    payload = Map.get(input, :payload) || Map.get(input, "payload", %{})

    case execute_action(action, payload) do
      {:ok, result} ->
        {:ok, %{action: action, result: result}}

      {:error, reason} ->
        {:error, "YouTubeLiveStreamingPrism error on action '#{action}': #{inspect(reason)}"}
    end
  end

  defp execute_action("get_auth_url", payload) do
    client_id = Map.get(payload, :client_id, Map.get(payload, "client_id", "sample_client_id"))
    redirect_uri = Map.get(payload, :redirect_uri, Map.get(payload, "redirect_uri", "http://localhost:8080/oauth/callback"))
    url = LiveStreaming.generate_auth_url(client_id, redirect_uri)
    {:ok, %{auth_url: url}}
  end

  defp execute_action("initiate_upload", payload) do
    metadata = Map.get(payload, :metadata, Map.get(payload, "metadata", %{}))
    size = Map.get(payload, :total_bytes, Map.get(payload, "total_bytes", 10_000_000))
    LiveStreaming.initiate_resumable_upload(metadata, size)
  end

  defp execute_action("upload_chunk", payload) do
    session = Map.get(payload, :session, Map.get(payload, "session", %{}))
    chunk_size = Map.get(payload, :chunk_size, Map.get(payload, "chunk_size", 1000))
    LiveStreaming.upload_chunk(session, chunk_size)
  end

  defp execute_action("create_broadcast", payload) do
    LiveStreaming.create_live_broadcast(payload)
  end

  defp execute_action("transition_broadcast", payload) do
    broadcast = Map.get(payload, :broadcast, Map.get(payload, "broadcast", %{}))
    target = Map.get(payload, :target_status, Map.get(payload, "target_status", :live))
    LiveStreaming.transition_broadcast(broadcast, target)
  end

  defp execute_action("check_stream_health", payload) do
    stream_id = Map.get(payload, :stream_id, Map.get(payload, "stream_id", "stream_01"))
    telemetry = Map.get(payload, :telemetry, Map.get(payload, "telemetry", %{}))
    {:ok, LiveStreaming.evaluate_health(stream_id, telemetry)}
  end

  defp execute_action("process_chat", payload) do
    items = Map.get(payload, :items, Map.get(payload, "items", []))
    {:ok, LiveStreaming.process_chat_batch(items)}
  end

  defp execute_action("respond_to_chat", payload) do
    msg = Map.get(payload, :message, Map.get(payload, "message", %{}))
    reply = LiveStreaming.generate_chat_response(msg)
    {:ok, %{reply: reply}}
  end

  defp execute_action("setup_automated_stream", payload) do
    LiveStreaming.setup_automated_stream(payload)
  end

  defp execute_action(unknown, _payload) do
    {:error, "Unknown action: #{unknown}"}
  end
end
