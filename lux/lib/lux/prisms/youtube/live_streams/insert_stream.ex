defmodule Lux.Prisms.YouTube.LiveStreams.InsertStream do
  @moduledoc "Creates YouTube live stream resources with quality controls."

  use Lux.Prism,
    name: "Create YouTube Live Stream",
    description: "Creates a YouTube live stream resource and validates ingestion quality settings",
    input_schema: %{
      type: :object,
      properties: %{
        title: %{type: :string},
        description: %{type: :string},
        ingestion_type: %{type: :string, enum: ["dash", "rtmp"]},
        resolution: %{type: :string, enum: ["240p", "360p", "480p", "720p", "1080p", "1440p", "variable"]},
        frame_rate: %{type: :string, enum: ["30fps", "60fps", "variable"]}
      },
      required: ["title"]
    }

  alias Lux.Integrations.YouTube.Client

  @valid_resolutions ~w(1080p 1440p 240p 360p 480p 720p variable)
  @valid_frame_rates ~w(30fps 60fps variable)
  @valid_ingestion_types ~w(dash rtmp)

  def handler(params, _agent) do
    with {:ok, title} <- required(params, :title),
         {:ok, ingestion_type} <- validate_choice(value(params, :ingestion_type, "rtmp"), @valid_ingestion_types, :ingestion_type),
         {:ok, resolution} <- validate_choice(value(params, :resolution, "variable"), @valid_resolutions, :resolution),
         {:ok, frame_rate} <- validate_choice(value(params, :frame_rate, "variable"), @valid_frame_rates, :frame_rate),
         {:ok, response} <- Client.request(:post, "/liveStreams", %{
           params: %{part: "snippet,cdn,status"},
           json: %{
             snippet: %{
               title: title,
               description: value(params, :description, "")
             },
             cdn: %{
               ingestionType: ingestion_type,
               resolution: resolution,
               frameRate: frame_rate
             }
           }
         }) do
      {:ok, normalize(response)}
    end
  end

  defp normalize(response) do
    snippet = response["snippet"] || %{}
    status = response["status"] || %{}
    cdn = response["cdn"] || %{}

    %{
      id: response["id"],
      title: snippet["title"],
      stream_status: status["streamStatus"],
      resolution: cdn["resolution"],
      frame_rate: cdn["frameRate"],
      ingestion_type: cdn["ingestionType"]
    }
  end

  defp validate_choice(value, allowed, key) do
    if value in allowed do
      {:ok, value}
    else
      {:error, "Invalid #{key}. Expected one of: #{Enum.join(allowed, ", ")}"}
    end
  end

  defp required(params, key) do
    case value(params, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp value(params, key, default \\ nil), do: Map.get(params, key) || Map.get(params, to_string(key)) || default
end
