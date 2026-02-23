defmodule Lux.Lenses.YouTube.Creation.ListPlaylistItems do
  @moduledoc """
  A lens for listing items (videos) within a YouTube playlist.

  Fetches playlist items from the YouTube Data API v3 /playlistItems endpoint,
  returning the ordered list of videos with their title, video ID, position,
  and thumbnail URL.

  ## Authentication

  Uses YouTube Data API key. Configure in application config:

      config :lux, :api_keys, youtube: "your_youtube_api_key"

  ## Examples

      iex> ListPlaylistItems.focus(%{"playlist_id" => "PLxxxxxx"})
      {:ok, %{
        items: [
          %{
            playlist_item_id: "PLxxxxxxxx_0",
            video_id: "dQw4w9WgXcQ",
            title: "Never Gonna Give You Up",
            description: "Official music video",
            position: 0,
            published_at: "2009-10-25T06:57:33Z",
            channel_title: "Rick Astley",
            thumbnail_url: "https://..."
          }
        ],
        playlist_id: "PLxxxxxx",
        count: 1
      }}
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "List YouTube Playlist Items",
    description: "Lists videos within a YouTube playlist from the YouTube Data API v3",
    url: "https://www.googleapis.com/youtube/v3/playlistItems",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.api_key_auth(),
    schema: %{
      type: :object,
      properties: %{
        playlist_id: %{
          type: :string,
          description: "The ID of the playlist to list items from"
        },
        max_results: %{
          type: :integer,
          description: "Maximum number of results to return (1-50)"
        }
      },
      required: ["playlist_id"]
    }

  @doc """
  Builds the query parameters for the YouTube playlistItems endpoint.
  """
  @impl true
  def before_focus(params) do
    playlist_id = params["playlist_id"] || params[:playlist_id]
    max_results = params["max_results"] || params[:max_results] || 50

    {:ok, %{
      "playlistId" => playlist_id,
      "part" => "snippet,contentDetails",
      "maxResults" => max_results
    }}
  end

  @doc """
  Transforms the YouTube API response into structured playlist item data.
  """
  @impl true
  def after_focus(%{"items" => items} = response) when is_list(items) do
    playlist_id =
      case items do
        [first | _] -> get_in(first, ["snippet", "playlistId"])
        [] -> nil
      end

    result_items =
      Enum.map(items, fn item ->
        snippet = item["snippet"] || %{}
        content = item["contentDetails"] || %{}

        %{
          playlist_item_id: item["id"],
          video_id: get_in(snippet, ["resourceId", "videoId"]) || content["videoId"],
          title: snippet["title"],
          description: snippet["description"],
          position: snippet["position"],
          published_at: snippet["publishedAt"],
          channel_title: snippet["channelTitle"],
          thumbnail_url: get_in(snippet, ["thumbnails", "high", "url"])
        }
      end)

    {:ok, %{
      items: result_items,
      playlist_id: playlist_id || response["pageInfo"]["totalResults"] |> to_string(),
      count: length(result_items)
    }}
  end

  def after_focus(%{"error" => %{"message" => message, "code" => code}}) do
    {:error, %{message: message, code: code}}
  end

  def after_focus(response) do
    {:error, %{message: "Unexpected response", detail: inspect(response)}}
  end
end
