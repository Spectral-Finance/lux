defmodule Lux.Prisms.YouTube.YouTubeVideoPrism do
  @moduledoc """
  A prism for managing YouTube videos - list, get, update, delete.
  """

  use Lux.Prism,
    name: "YouTube Video Manager",
    description: "Manages YouTube videos via YouTube Data API v3",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, enum: ["list", "get", "update", "delete"]},
        video_id: %{type: :string},
        title: %{type: :string},
        description: %{type: :string},
        tags: %{type: :array},
        max_results: %{type: :integer, default: 10}
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        videos: %{type: :array},
        video: %{type: :object}
      },
      required: ["status"]
    }

  require Logger

  @api "https://www.googleapis.com/youtube/v3"

  def handler(input, _ctx) do
    with {:ok, api_key} <- get_api_key() do
      case input.action do
        "list"   -> list_videos(api_key, input)
        "get"    -> get_video(api_key, input.video_id)
        "update" -> update_video(api_key, input)
        "delete" -> delete_video(api_key, input.video_id)
        _        -> {:error, "Unknown action: #{input.action}"}
      end
    end
  end

  defp get_api_key do
    key = Lux.Config.get(:youtube_api_key) || System.get_env("YOUTUBE_API_KEY")
    if key, do: {:ok, key}, else: {:error, "YouTube API key not configured"}
  rescue
    _ -> {:error, "YouTube API key not configured"}
  end

  defp list_videos(api_key, input) do
    case Req.get("#{@api}/videos",
      params: %{part: "snippet,statistics", mine: true, maxResults: Map.get(input, :max_results, 10), key: api_key}
    ) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, %{status: "success", videos: Enum.map(body["items"] || [], &parse_video/1)}}
      {:ok, %{status: s, body: b}} -> {:error, "Error #{s}: #{inspect(b)}"}
      {:error, r} -> {:error, inspect(r)}
    end
  end

  defp get_video(api_key, video_id) do
    case Req.get("#{@api}/videos", params: %{part: "snippet,statistics", id: video_id, key: api_key}) do
      {:ok, %{status: 200, body: %{"items" => [v | _]}}} -> {:ok, %{status: "success", video: parse_video(v)}}
      {:ok, %{status: 200}} -> {:error, "Video not found"}
      {:ok, %{status: s, body: b}} -> {:error, "Error #{s}: #{inspect(b)}"}
      {:error, r} -> {:error, inspect(r)}
    end
  end

  defp update_video(api_key, input) do
    case Req.put("#{@api}/videos?part=snippet&key=#{api_key}",
      json: %{id: input.video_id, snippet: %{title: input[:title], description: input[:description], tags: input[:tags] || []}}
    ) do
      {:ok, %{status: 200, body: b}} -> {:ok, %{status: "success", video: parse_video(b)}}
      {:ok, %{status: s, body: b}} -> {:error, "Error #{s}: #{inspect(b)}"}
      {:error, r} -> {:error, inspect(r)}
    end
  end

  defp delete_video(api_key, video_id) do
    case Req.delete("#{@api}/videos?id=#{video_id}&key=#{api_key}") do
      {:ok, %{status: 204}} -> {:ok, %{status: "success", message: "Deleted #{video_id}"}}
      {:ok, %{status: s, body: b}} -> {:error, "Error #{s}: #{inspect(b)}"}
      {:error, r} -> {:error, inspect(r)}
    end
  end

  defp parse_video(item) do
    %{
      id: item["id"],
      title: get_in(item, ["snippet", "title"]),
      description: get_in(item, ["snippet", "description"]),
      views: get_in(item, ["statistics", "viewCount"]),
      likes: get_in(item, ["statistics", "likeCount"])
    }
  end
end
