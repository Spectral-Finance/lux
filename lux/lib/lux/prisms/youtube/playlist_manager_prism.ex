defmodule Lux.Prisms.YouTube.PlaylistManagerPrism do
  @moduledoc """
  Inserts a video into a YouTube playlist.
  """
  use Lux.Prism,
    name: "YouTube Playlist Manager",
    description: "Inserts a video into a YouTube playlist",
    input_schema: %{
      type: :object,
      properties: %{
        video_id: %{type: :string},
        playlist_id: %{type: :string},
        access_token: %{type: :string}
      },
      required: ["video_id", "playlist_id", "access_token"]
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
    playlist_id = input[:playlist_id] || input["playlist_id"]
    access_token = input[:access_token] || input["access_token"]

    opts = [
      url: "https://www.googleapis.com/youtube/v3/playlistItems",
      params: [part: "snippet"],
      headers: [
        {"Authorization", "Bearer #{access_token}"}
      ],
      json: %{
        snippet: %{
          playlistId: playlist_id,
          resourceId: %{
            kind: "youtube#video",
            videoId: video_id
          }
        }
      }
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))

    case Req.post(opts) do
      {:ok, %{status: 200}} ->
        {:ok, %{success: true}}
        
      {:ok, %{status: 403, body: %{"error" => %{"errors" => [%{"reason" => "quotaExceeded"} | _]}}}} ->
        {:error, :quota_exceeded}
        
      other ->
        {:error, "Insert failed: #{inspect(other)}"}
    end
  end
end
