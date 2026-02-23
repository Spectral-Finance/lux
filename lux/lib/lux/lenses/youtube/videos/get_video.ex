defmodule Lux.Lenses.YouTube.Videos.GetVideo do
  @moduledoc """
  A lens for retrieving YouTube video details, statistics, and content details.

  ## Authentication

  Uses optional API key via `key` query parameter. Configure in application config:

      config :lux, :api_keys, youtube_api_key: "your_api_key"

  ## Examples

      iex> GetVideo.focus(%{
      ...>   video_id: "dQw4w9WgXcQ"
      ...> })
      {:ok, %{
        id: "dQw4w9WgXcQ",
        title: "Rick Astley - Never Gonna Give You Up",
        channel_id: "UCuAXFkgsw1L7xaCfnd5JJOw",
        channel_title: "Rick Astley",
        view_count: 1500000000,
        like_count: 15000000,
        duration: "PT3M33S",
        live_broadcast_content: "none"
      }}
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "Get YouTube Video",
    description: "Retrieves video metadata, statistics, and content details from YouTube",
    url: "https://www.googleapis.com/youtube/v3/videos",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.api_key_auth(),
    schema: %{
      type: :object,
      properties: %{
        video_id: %{
          type: :string,
          description: "The YouTube video ID (11-character string)"
        }
      },
      required: ["video_id"]
    }

  @impl true
  def before_focus(params) do
    video_id = params["video_id"] || params[:video_id]
    {:ok, %{
      "id" => video_id,
      "part" => "snippet,statistics,contentDetails,status,liveStreamingDetails"
    }}
  end

  @impl true
  def after_focus(%{"items" => [video | _]}) do
    snippet = video["snippet"] || %{}
    stats = video["statistics"] || %{}
    content = video["contentDetails"] || %{}
    status = video["status"] || %{}
    live = video["liveStreamingDetails"] || %{}

    result = %{
      id: video["id"],
      title: snippet["title"],
      description: snippet["description"],
      channel_id: snippet["channelId"],
      channel_title: snippet["channelTitle"],
      published_at: snippet["publishedAt"],
      thumbnail_url: get_in(snippet, ["thumbnails", "high", "url"]),
      tags: snippet["tags"],
      category_id: snippet["categoryId"],
      live_broadcast_content: snippet["liveBroadcastContent"],
      duration: content["duration"],
      definition: content["definition"],
      caption: content["caption"],
      privacy_status: status["privacyStatus"],
      upload_status: status["uploadStatus"],
      view_count: parse_int(stats["viewCount"]),
      like_count: parse_int(stats["likeCount"]),
      comment_count: parse_int(stats["commentCount"]),
      favorite_count: parse_int(stats["favoriteCount"]),
      scheduled_start_time: live["scheduledStartTime"],
      actual_start_time: live["actualStartTime"],
      actual_end_time: live["actualEndTime"],
      concurrent_viewers: parse_int(live["concurrentViewers"])
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()

    {:ok, result}
  end

  def after_focus(%{"items" => []}) do
    {:error, %{message: "Video not found"}}
  end

  def after_focus(%{"error" => %{"message" => msg}}) do
    {:error, %{message: msg}}
  end

  def after_focus(response) do
    {:error, %{title: "Unexpected response", detail: inspect(response)}}
  end

  defp parse_int(nil), do: nil
  defp parse_int(s) when is_binary(s) do
    case Integer.parse(s) do
      {i, ""} -> i
      _ -> nil
    end
  end
  defp parse_int(i) when is_integer(i), do: i
end
