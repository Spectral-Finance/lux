defmodule Lux.Prisms.YouTube.Live.CreateStream do
  @moduledoc """
  Creates a YouTube live stream ingestion resource.
  """

  use Lux.Prism,
    name: "Create YouTube Live Stream",
    description: "Creates a YouTube RTMP live stream ingest resource",
    input_schema: %{
      type: :object,
      properties: %{
        title: %{type: :string, description: "Stream title"},
        ingestion_type: %{type: :string, description: "Ingestion type", enum: ["rtmp"]},
        resolution: %{type: :string, description: "Stream resolution"},
        frame_rate: %{type: :string, description: "Frame rate"},
        token: %{type: :string, description: "Optional OAuth2 access token"}
      },
      required: ["title"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        stream_id: %{type: :string, description: "Created stream ID"},
        title: %{type: :string, description: "Stream title"}
      },
      required: ["stream_id", "title"]
    }

  alias Lux.Integrations.YouTube.Client

  def handler(params, _agent) do
    with {:ok, title} <- validate_string(params, :title) do
      stream = %{
        snippet: %{title: title},
        cdn: %{
          ingestionType: Map.get(params, :ingestion_type, "rtmp"),
          resolution: Map.get(params, :resolution, "1080p"),
          frameRate: Map.get(params, :frame_rate, "30fps")
        }
      }

      case Client.insert_live_stream(stream, request_opts(params)) do
        {:ok, %{"id" => stream_id}} -> {:ok, %{stream_id: stream_id, title: title}}
        {:error, error} -> {:error, "Failed to create YouTube stream: #{inspect(error)}"}
      end
    end
  end

  defp validate_string(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp request_opts(%{token: token}) when is_binary(token) and token != "", do: %{token: token}
  defp request_opts(_params), do: %{}
end
