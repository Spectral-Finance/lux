defmodule Lux.Prisms.YouTube.Live.CreateStream do
  @moduledoc """
  Creates a reusable YouTube live stream ingestion target.
  """

  use Lux.Prism,
    name: "Create YouTube Live Stream",
    description: "Creates a YouTube live stream with CDN ingestion settings",
    input_schema: %{
      type: :object,
      properties: %{
        title: %{type: :string, description: "Stream title"},
        description: %{type: :string, description: "Stream description"},
        ingestion_type: %{type: :string, enum: ["rtmp"], default: "rtmp"},
        resolution: %{
          type: :string,
          enum: ["240p", "360p", "480p", "720p", "1080p", "1440p", "2160p"],
          default: "1080p"
        },
        frame_rate: %{type: :string, enum: ["30fps", "60fps"], default: "30fps"}
      },
      required: ["title"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        id: %{type: :string},
        title: %{type: :string},
        ingestion_type: %{type: :string},
        resolution: %{type: :string},
        frame_rate: %{type: :string},
        ready_for_live: %{type: :boolean}
      },
      required: ["id", "title"]
    }

  alias Lux.Integrations.YouTube.Client
  alias Lux.Integrations.YouTube.LiveStream

  def handler(params, _agent) do
    with {:ok, title} <- required(params, :title) do
      body = %{
        snippet: %{
          title: title,
          description: params[:description] || ""
        },
        cdn: %{
          ingestionType: params[:ingestion_type] || "rtmp",
          resolution: params[:resolution] || "1080p",
          frameRate: params[:frame_rate] || "30fps"
        }
      }

      opts = [
        token: params[:token],
        params: %{part: "snippet,cdn,status"},
        json: body,
        plug: params[:plug]
      ]

      case Client.request(:post, "/liveStreams", opts) do
        {:ok, response} -> {:ok, LiveStream.normalize_stream(response)}
        {:error, error} -> {:error, error}
      end
    end
  end

  defp required(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
