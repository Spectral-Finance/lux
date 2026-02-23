defmodule Lux.Prisms.YouTube.CreateStream do
  @moduledoc """
  A prism for creating a YouTube live stream and binding it to a broadcast.

  Creates an RTMP live stream with the specified resolution and frame rate,
  then binds it to an existing broadcast. After binding, use TransitionBroadcast
  to move from testing to live.

  ## Authentication

  Requires OAuth2 token with `youtube` scope.

      config :lux, :api_keys, youtube_oauth_token: "your_oauth2_token"

  ## Examples

      iex> CreateStream.handler(%{
      ...>   title: "My Stream",
      ...>   broadcast_id: "broadcastId...",
      ...>   resolution: "1080p",
      ...>   frame_rate: "30fps"
      ...> }, %{name: "Agent"})
      {:ok, %{
        stream_id: "newStreamId",
        title: "My Stream",
        ingestion_address: "rtmp://a.rtmp.youtube.com/live2",
        stream_key: "xxxx-xxxx-xxxx-xxxx",
        bound_to_broadcast: "broadcastId...",
        status: "created"
      }}
  """

  use Lux.Prism,
    name: "Create YouTube Live Stream",
    description: "Creates a live stream and optionally binds it to a broadcast",
    input_schema: %{
      type: :object,
      properties: %{
        title: %{
          type: :string,
          description: "The stream title",
          maxLength: 128
        },
        broadcast_id: %{
          type: :string,
          description: "Broadcast ID to bind this stream to (optional)"
        },
        resolution: %{
          type: :string,
          description: "Stream resolution",
          enum: ["240p", "360p", "480p", "720p", "1080p", "1440p", "2160p"],
          default: "1080p"
        },
        frame_rate: %{
          type: :string,
          description: "Stream frame rate",
          enum: ["30fps", "60fps"],
          default: "30fps"
        },
        ingestion_type: %{
          type: :string,
          description: "Ingestion protocol",
          enum: ["rtmp", "dash", "webrtc"],
          default: "rtmp"
        }
      },
      required: ["title"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        stream_id: %{type: :string},
        title: %{type: :string},
        ingestion_address: %{type: :string},
        stream_key: %{type: :string},
        bound_to_broadcast: %{type: :string},
        status: %{type: :string}
      }
    }

  alias Lux.Integrations.YouTube

  @stream_url "https://www.googleapis.com/youtube/v3/liveStreams"
  @bind_url "https://www.googleapis.com/youtube/v3/liveBroadcasts/bind"

  @impl true
  def handler(params, _agent_ctx) do
    title = params["title"] || params[:title]
    broadcast_id = params["broadcast_id"] || params[:broadcast_id]
    resolution = params["resolution"] || params[:resolution] || "1080p"
    frame_rate = params["frame_rate"] || params[:frame_rate] || "30fps"
    ingestion_type = params["ingestion_type"] || params[:ingestion_type] || "rtmp"

    oauth_token = Application.get_env(:lux, :api_keys)[:youtube_oauth_token]
    headers = YouTube.headers() ++ [{"Authorization", "Bearer #{oauth_token}"}]

    body = %{
      snippet: %{title: title},
      cdn: %{
        frameRate: frame_rate,
        ingestionType: ingestion_type,
        resolution: resolution
      },
      contentDetails: %{isReusable: false}
    }

    with {:ok, %{status: s, body: stream_resp}} when s in 200..299 <-
           Req.post(@stream_url, json: body, params: %{"part" => "snippet,cdn,status,contentDetails"}, headers: headers),
         stream_id <- stream_resp["id"],
         ingestion <- get_in(stream_resp, ["cdn", "ingestionInfo"]) || %{},
         result <- %{
           stream_id: stream_id,
           title: get_in(stream_resp, ["snippet", "title"]),
           ingestion_address: ingestion["ingestionAddress"],
           stream_key: ingestion["streamName"],
           rtmp_ingestion_address: ingestion["rtmpsIngestionAddress"],
           status: "created"
         } |> Enum.reject(fn {_k, v} -> is_nil(v) end) |> Map.new() do

      if broadcast_id do
        case Req.post(@bind_url,
          params: %{"id" => broadcast_id, "streamId" => stream_id, "part" => "id,contentDetails"},
          headers: headers,
          body: ""
        ) do
          {:ok, %{status: bs}} when bs in 200..299 ->
            {:ok, Map.put(result, :bound_to_broadcast, broadcast_id)}
          {:ok, %{body: %{"error" => %{"message" => msg}}}} ->
            {:error, %{message: "Stream created but bind failed: #{msg}", stream_id: stream_id}}
          _ ->
            {:ok, Map.put(result, :bind_error, "Failed to bind to broadcast")}
        end
      else
        {:ok, result}
      end
    else
      {:ok, %{body: %{"error" => %{"message" => msg}}}} ->
        {:error, %{message: msg}}
      {:error, reason} ->
        {:error, %{message: inspect(reason)}}
    end
  end
end
