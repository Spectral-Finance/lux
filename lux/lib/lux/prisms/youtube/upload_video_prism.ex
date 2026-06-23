defmodule Lux.Prisms.YouTube.UploadVideoPrism do
  @moduledoc """
  Uploads a video to YouTube using resumable upload.
  """
  use Lux.Prism,
    name: "YouTube Video Upload",
    description: "Uploads a video to YouTube using resumable upload",
    input_schema: %{
      type: :object,
      properties: %{
        video_path: %{type: :string},
        access_token: %{type: :string},
        title: %{type: :string},
        description: %{type: :string}
      },
      required: ["video_path", "access_token"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        video_id: %{type: :string}
      },
      required: ["video_id"]
    }

  def handler(input, _ctx) do
    video_path = input[:video_path] || input["video_path"]
    access_token = input[:access_token] || input["access_token"]
    title = input[:title] || input["title"] || "Untitled"
    description = input[:description] || input["description"] || ""

    if not File.exists?(video_path) do
      {:error, "Video file not found"}
    else
      file_size = File.stat!(video_path).size

      # 1. Initiate resumable upload
      init_opts = [
        url: "https://www.googleapis.com/upload/youtube/v3/videos",
        params: [uploadType: "resumable", part: "snippet,status"],
        headers: [
          {"Authorization", "Bearer #{access_token}"},
          {"X-Upload-Content-Length", to_string(file_size)},
          {"X-Upload-Content-Type", "video/mp4"}
        ],
        json: %{
          snippet: %{
            title: title,
            description: description
          },
          status: %{
            privacyStatus: "private"
          }
        }
      ]
      |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))

      case Req.post(init_opts) do
        {:ok, %{status: 200, headers: headers}} ->
          location = get_header(headers, "location")
          
          if location do
            # 2. Upload video
            upload_opts = [
              url: location,
              body: File.read!(video_path),
              headers: [
                {"Authorization", "Bearer #{access_token}"},
                {"Content-Type", "video/mp4"}
              ]
            ]
            |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))

            case Req.put(upload_opts) do
              {:ok, %{status: 200, body: body}} ->
                {:ok, %{video_id: body["id"]}}
                
              {:ok, %{status: 403, body: %{"error" => %{"errors" => [%{"reason" => "quotaExceeded"} | _]}}}} ->
                {:error, :quota_exceeded}
                
              other ->
                {:error, "Upload failed: #{inspect(other)}"}
            end
          else
            {:error, "No location header in initiation response"}
          end

        {:ok, %{status: 403, body: %{"error" => %{"errors" => [%{"reason" => "quotaExceeded"} | _]}}}} ->
          {:error, :quota_exceeded}

        other ->
          {:error, "Initiation failed: #{inspect(other)}"}
      end
    end
  end

  defp get_header(headers, key) do
    Enum.find_value(headers, fn {k, v} -> 
      if String.downcase(k) == key, do: List.first(List.wrap(v))
    end)
  end
end
