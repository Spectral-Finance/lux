defmodule Lux.Prisms.YouTube.ManageStream do
  @moduledoc "Create and manage YouTube live streams (the actual stream endpoint)."

  use Lux.Prism,
    name: "YouTube Manage Stream",
    description: "Create or delete live stream endpoints",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, enum: ["create", "delete"]},
        title: %{type: :string},
        resolution: %{type: :string, enum: ["240p", "360p", "480p", "720p", "1080p", "1440p", "2160p"]},
        frame_rate: %{type: :string, enum: ["30fps", "60fps"]},
        stream_id: %{type: :string},
        access_token: %{type: :string}
      },
      required: ["action", "access_token"]
    }

  alias Lux.Integrations.YouTube.Client

  def handler(params, _context) do
    action = params[:action] || params["action"]
    token = params[:access_token] || params["access_token"]
    plug = params[:plug]

    case to_string(action) do
      "create" -> create_stream(params, token, plug)
      "delete" -> delete_stream(params, token, plug)
      _ -> {:error, "Unknown action: #{action}"}
    end
  end

  defp create_stream(params, token, plug) do
    title = params[:title] || params["title"] || "Live Stream"
    resolution = params[:resolution] || params["resolution"] || "1080p"
    frame_rate = params[:frame_rate] || params["frame_rate"] || "30fps"

    body = %{
      snippet: %{title: title},
      cdn: %{
        frameRate: frame_rate,
        resolution: resolution,
        ingestionType: "rtmp"
      }
    }

    Client.request(:post, "/liveStreams?part=snippet,cdn,status", %{
      json: body, auth_type: :oauth2, access_token: token, plug: plug
    })
    |> case do
      {:ok, data} ->
        {:ok, %{
          stream_id: data["id"],
          title: get_in(data, ["snippet", "title"]),
          ingestion_address: get_in(data, ["cdn", "ingestionInfo", "ingestionAddress"]),
          stream_name: get_in(data, ["cdn", "ingestionInfo", "streamName"]),
          status: get_in(data, ["status", "streamStatus"])
        }}
      error -> error
    end
  end

  defp delete_stream(params, token, plug) do
    id = params[:stream_id] || params["stream_id"]
    Client.request(:delete, "/liveStreams?id=#{id}", %{
      auth_type: :oauth2, access_token: token, plug: plug
    })
    |> case do
      {:ok, _} -> {:ok, %{deleted: true, stream_id: id}}
      error -> error
    end
  end
end
