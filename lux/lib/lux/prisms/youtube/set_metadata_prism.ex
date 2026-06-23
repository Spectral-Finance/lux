defmodule Lux.Prisms.YouTube.SetMetadataPrism do
  @moduledoc """
  Updates video metadata on YouTube.
  """
  use Lux.Prism,
    name: "YouTube Set Metadata",
    description: "Updates metadata for a YouTube video",
    input_schema: %{
      type: :object,
      properties: %{
        video_id: %{type: :string},
        title: %{type: :string},
        description: %{type: :string},
        tags: %{type: :array, items: %{type: :string}},
        access_token: %{type: :string}
      },
      required: ["video_id", "access_token"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        success: %{type: :boolean}
      },
      required: ["success"]
    }

  def handler(input, _ctx) do
    video_id = input[:video_id] || input["video_id"]
    access_token = input[:access_token] || input["access_token"]
    title = input[:title] || input["title"] || "Untitled"
    description = input[:description] || input["description"] || ""
    tags = input[:tags] || input["tags"] || []

    opts = [
      url: "https://www.googleapis.com/youtube/v3/videos",
      params: [part: "snippet"],
      headers: [
        {"Authorization", "Bearer #{access_token}"}
      ],
      json: %{
        id: video_id,
        snippet: %{
          title: title,
          description: description,
          tags: tags,
          categoryId: "22"
        }
      }
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))

    case Req.put(opts) do
      {:ok, %{status: 200}} ->
        {:ok, %{success: true}}
        
      {:ok, %{status: 403, body: %{"error" => %{"errors" => [%{"reason" => "quotaExceeded"} | _]}}}} ->
        {:error, :quota_exceeded}
        
      other ->
        {:error, "Update failed: #{inspect(other)}"}
    end
  end
end
