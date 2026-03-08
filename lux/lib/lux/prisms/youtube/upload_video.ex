defmodule Lux.Prisms.YouTube.UploadVideo do
  @moduledoc "Upload a video to YouTube."

  use Lux.Prism,
    name: "YouTube Upload Video",
    description: "Upload a video to YouTube with metadata",
    input_schema: %{
      type: :object,
      properties: %{
        title: %{type: :string},
        description: %{type: :string},
        tags: %{type: :array, items: %{type: :string}},
        category_id: %{type: :string},
        privacy_status: %{type: :string, enum: ["public", "private", "unlisted"]},
        file_path: %{type: :string},
        access_token: %{type: :string}
      },
      required: ["title", "file_path", "access_token"]
    }

  alias Lux.Integrations.YouTube
  alias Lux.Integrations.YouTube.Client

  def handler(params, _context) do
    title = to_s(params, :title)
    description = to_s(params, :description) || ""
    tags = params[:tags] || params["tags"] || []
    category_id = to_s(params, :category_id) || "22"
    privacy = to_s(params, :privacy_status) || "private"
    access_token = to_s(params, :access_token)

    metadata = %{
      snippet: %{title: title, description: description, tags: tags, categoryId: category_id},
      status: %{privacyStatus: privacy}
    }

    # Initiate resumable upload
    Client.request(:post, "/videos?uploadType=resumable&part=snippet,status", %{
      base_url: YouTube.upload_url(),
      json: metadata,
      auth_type: :oauth2,
      access_token: access_token,
      plug: params[:plug]
    })
    |> case do
      {:ok, data} -> {:ok, format_video(data)}
      {:error, e} -> {:error, e}
    end
  end

  defp format_video(data) do
    %{
      video_id: data["id"],
      title: get_in(data, ["snippet", "title"]),
      status: get_in(data, ["status", "uploadStatus"]),
      privacy: get_in(data, ["status", "privacyStatus"])
    }
  end

  defp to_s(p, k), do: p[k] || p[Atom.to_string(k)]
end
