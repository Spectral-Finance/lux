defmodule Lux.Lenses.YouTube.GetVideoDetails do
  @moduledoc """
  A lens for fetching detailed information about a YouTube video.
  This lens provides a simple interface for getting video details with:
  - Video ID as the required parameter
  - Configurable parts (snippet, statistics, contentDetails, etc.)
  - Direct YouTube API error propagation
  - Clean response structure

  ## Examples
      iex> GetVideoDetails.focus(%{
      ...>   video_id: "dQw4w9WgXcQ"
      ...> })
      {:ok, %{
        video_id: "dQw4w9WgXcQ",
        title: "Rick Astley - Never Gonna Give You Up",
        description: "The official video...",
        channel_title: "Rick Astley",
        published_at: "2009-10-25T06:57:33Z",
        view_count: "1500000000",
        like_count: "15000000",
        duration: "PT3M33S",
        thumbnail_url: "https://i.ytimg.com/vi/dQw4w9WgXcQ/default.jpg"
      }}
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "Get YouTube Video Details",
    description: "Fetches detailed information about a specific YouTube video",
    url: "https://www.googleapis.com/youtube/v3/videos",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.auth(),
    schema: %{
      type: :object,
      properties: %{
        id: %{
          type: :string,
          description: "The YouTube video ID"
        },
        part: %{
          type: :string,
          description: "API resource parts to include",
          default: "snippet,statistics,contentDetails"
        }
      },
      required: ["id"]
    }

  @doc """
  Transforms the YouTube API response into a simpler format.
  """
  @impl true
  def after_focus(%{"items" => [item | _]}) do
    snippet = item["snippet"] || %{}
    statistics = item["statistics"] || %{}
    content_details = item["contentDetails"] || %{}

    {:ok, %{
      video_id: item["id"],
      title: snippet["title"],
      description: snippet["description"],
      channel_title: snippet["channelTitle"],
      published_at: snippet["publishedAt"],
      view_count: statistics["viewCount"],
      like_count: statistics["likeCount"],
      comment_count: statistics["commentCount"],
      duration: content_details["duration"],
      thumbnail_url: get_in(snippet, ["thumbnails", "default", "url"])
    }}
  end

  def after_focus(%{"items" => []}) do
    {:error, %{"message" => "Video not found"}}
  end

  def after_focus(%{"error" => %{"message" => message}}) do
    {:error, %{"message" => message}}
  end
end
