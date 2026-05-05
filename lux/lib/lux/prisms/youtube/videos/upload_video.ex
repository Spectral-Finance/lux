defmodule Lux.Prisms.YouTube.Videos.UploadVideo do
  @moduledoc "Uploads video bytes to YouTube using a resumable upload session."

  use Lux.Prism,
    name: "Upload YouTube Video",
    description: "Creates a resumable upload session and uploads video bytes to YouTube",
    input_schema: %{
      type: :object,
      properties: %{
        title: %{type: :string},
        description: %{type: :string},
        privacy_status: %{type: :string, enum: ["private", "public", "unlisted"]},
        mime_type: %{type: :string},
        video_data: %{type: :string, description: "Binary video payload"}
      },
      required: ["title", "video_data"]
    }

  alias Lux.Integrations.YouTube.Client

  def handler(params, _agent) do
    with {:ok, title} <- required(params, :title),
         {:ok, video_data} <- required_binary(params, :video_data),
         {:ok, %{"upload_url" => upload_url}} <-
           Client.request(:post, "/videos", upload_request(params, title, video_data)),
         {:ok, response} <-
           Client.upload_content(upload_url, video_data, %{
             headers: [{"Content-Type", mime_type(params)}]
           }) do
      {:ok, normalize(response)}
    end
  end

  defp upload_request(params, title, video_data) do
    mime_type = mime_type(params)

    %{
      endpoint: :upload,
      params: %{uploadType: "resumable", part: "snippet,status"},
      headers: [
        {"X-Upload-Content-Type", mime_type},
        {"X-Upload-Content-Length", to_string(byte_size(video_data))}
      ],
      json: %{
        snippet: %{
          title: title,
          description: value(params, :description, "")
        },
        status: %{
          privacyStatus: value(params, :privacy_status, "private"),
          selfDeclaredMadeForKids: value(params, :self_declared_made_for_kids, false)
        }
      }
    }
  end

  defp normalize(response) do
    status = response["status"] || %{}

    %{
      uploaded: true,
      video_id: response["id"],
      upload_status: status["uploadStatus"] || "uploaded"
    }
  end

  defp required(params, key) do
    case value(params, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp required_binary(params, key) do
    case value(params, key) do
      value when is_binary(value) and byte_size(value) > 0 -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp mime_type(params),
    do: value(params, :mime_type) || value(params, :content_type, "video/mp4")

  defp value(params, key, default \\ nil),
    do: Map.get(params, key) || Map.get(params, to_string(key)) || default
end
