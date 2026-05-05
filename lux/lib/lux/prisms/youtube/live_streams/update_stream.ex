defmodule Lux.Prisms.YouTube.LiveStreams.UpdateStream do
  @moduledoc "Updates a YouTube live stream's metadata and quality controls."

  use Lux.Prism,
    name: "Update YouTube Live Stream",
    description:
      "Updates a YouTube live stream metadata, ingestion, resolution, and frame-rate settings",
    input_schema: %{
      type: :object,
      properties: %{
        id: %{type: :string, description: "Live stream ID"},
        title: %{type: :string, description: "Updated stream title"},
        description: %{type: :string, description: "Updated stream description"},
        ingestion_type: %{type: :string, enum: ["dash", "rtmp"]},
        resolution: %{
          type: :string,
          enum: ["240p", "360p", "480p", "720p", "1080p", "1440p", "variable"]
        },
        frame_rate: %{type: :string, enum: ["30fps", "60fps", "variable"]}
      },
      required: ["id"]
    }

  alias Lux.Integrations.YouTube.Client

  @valid_ingestion_types ~w(dash rtmp)
  @valid_resolutions ~w(1080p 1440p 240p 360p 480p 720p variable)
  @valid_frame_rates ~w(30fps 60fps variable)

  def handler(params, _agent) do
    with {:ok, id} <- required(params, :id),
         :ok <-
           validate_choice(
             value(params, :ingestion_type),
             @valid_ingestion_types,
             :ingestion_type
           ),
         :ok <- validate_choice(value(params, :resolution), @valid_resolutions, :resolution),
         :ok <- validate_choice(value(params, :frame_rate), @valid_frame_rates, :frame_rate),
         {:ok, response} <-
           Client.request(:put, "/liveStreams", %{
             params: %{part: "snippet,cdn,status"},
             json: request_body(id, params)
           }) do
      {:ok, normalize(response)}
    end
  end

  defp request_body(id, params) do
    %{id: id}
    |> maybe_put_section(:snippet, snippet(params))
    |> maybe_put_section(:cdn, cdn(params))
  end

  defp snippet(params) do
    %{}
    |> maybe_put(:title, value(params, :title))
    |> maybe_put(:description, value(params, :description))
  end

  defp cdn(params) do
    %{}
    |> maybe_put(:ingestionType, value(params, :ingestion_type))
    |> maybe_put(:resolution, value(params, :resolution))
    |> maybe_put(:frameRate, value(params, :frame_rate))
  end

  defp normalize(response) do
    snippet = response["snippet"] || %{}
    cdn = response["cdn"] || %{}
    status = response["status"] || %{}

    %{
      id: response["id"],
      title: snippet["title"],
      resolution: cdn["resolution"],
      frame_rate: cdn["frameRate"],
      stream_status: status["streamStatus"]
    }
  end

  defp maybe_put_section(body, _key, section) when section == %{}, do: body
  defp maybe_put_section(body, key, section), do: Map.put(body, key, section)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp validate_choice(nil, _allowed, _key), do: :ok

  defp validate_choice(value, allowed, key) do
    if value in allowed do
      :ok
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

  defp value(params, key), do: Map.get(params, key) || Map.get(params, to_string(key))
end
