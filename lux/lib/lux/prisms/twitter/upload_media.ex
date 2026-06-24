defmodule Lux.Prisms.Twitter.UploadMedia do
  @moduledoc """
  A prism for uploading media via the Twitter API v1.1.
  """
  use Lux.Prism,
    name: "Upload Media",
    description: "Uploads an image, video, or GIF to Twitter.",
    input_schema: %{
      type: :object,
      properties: %{
        file_path: %{type: :string, description: "Local path to the media file"},
        media_type: %{type: :string, description: "Type of media (e.g., 'image/jpeg', 'video/mp4')"}
      },
      required: ["file_path"]
    }

  alias Lux.Integrations.Twitter.Client

  def handler(input, _ctx) do
    file_path = Map.get(input, "file_path") || Map.get(input, :file_path)
    media_type = Map.get(input, "media_type") || Map.get(input, :media_type) || "image/jpeg"
    
    if File.exists?(file_path) do
      Client.upload_media(file_path, media_type)
    else
      {:error, "File does not exist: #{file_path}"}
    end
  end
end
