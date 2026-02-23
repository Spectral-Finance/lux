defmodule Lux.Lenses.YouTube.Growth.ListTopVideos do
  @moduledoc """
  A lens for retrieving the most popular YouTube videos by region and category.

  Uses the YouTube Data API v3 `/videos` endpoint with `chart=mostPopular`
  to return trending video data including engagement metrics.

  ## Authentication

  Uses API key via `key` query parameter.

      config :lux, :api_keys, youtube: "your_api_key"

  ## Examples

      iex> ListTopVideos.focus(%{
      ...>   region_code: "US",
      ...>   video_category_id: "10",
      ...>   max_results: 10
      ...> })
      {:ok, %{
        videos: [
          %{
            id: "dQw4w9WgXcQ",
            title: "Top Video",
            channel_title: "TopChannel",
            view_count: 5_000_000,
            like_count: 250_000,
            comment_count: 15_000,
            engagement_rate: 5.3,
            published_at: "2024-01-15T12:00:00.000Z",
            thumbnail_url: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg"
          }
        ],
        total_results: 1
      }}
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "List Top YouTube Videos",
    description: "Retrieves trending YouTube videos by region and category with engagement metrics",
    url: "https://www.googleapis.com/youtube/v3/videos",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.api_key_auth(),
    schema: %{
      type: :object,
      properties: %{
        region_code: %{
          type: :string,
          description: "ISO 3166-1 alpha-2 country code (e.g. US, GB, JP)",
          default: "US"
        },
        video_category_id: %{
          type: :string,
          description: "YouTube video category ID to filter results (e.g. '10' for Music)"
        },
        max_results: %{
          type: :integer,
          description: "Maximum number of results to return (1-50)",
          minimum: 1,
          maximum: 50,
          default: 10
        },
        page_token: %{
          type: :string,
          description: "Page token for pagination"
        }
      },
      required: []
    }

  @impl true
  def before_focus(params) do
    query = %{
      "chart" => "mostPopular",
      "part" => "snippet,statistics",
      "maxResults" => params["max_results"] || params[:max_results] || 10,
      "regionCode" => params["region_code"] || params[:region_code] || "US"
    }

    query =
      case params["video_category_id"] || params[:video_category_id] do
        nil -> query
        cat_id -> Map.put(query, "videoCategoryId", cat_id)
      end

    query =
      case params["page_token"] || params[:page_token] do
        nil -> query
        token -> Map.put(query, "pageToken", token)
      end

    {:ok, query}
  end

  @impl true
  def after_focus(%{"items" => items, "pageInfo" => page_info}) do
    videos = Enum.map(items, &parse_video/1)
    {:ok, %{
      videos: videos,
      total_results: page_info["totalResults"] || length(videos)
    }}
  end

  def after_focus(%{"items" => []}) do
    {:ok, %{videos: [], total_results: 0}}
  end

  def after_focus(%{"error" => %{"message" => msg}}) do
    {:error, %{message: msg}}
  end

  def after_focus(response) do
    {:error, %{message: "Unexpected response", detail: inspect(response)}}
  end

  defp parse_video(item) do
    snippet = item["snippet"] || %{}
    stats = item["statistics"] || %{}

    view_count = parse_int(stats["viewCount"]) || 0
    like_count = parse_int(stats["likeCount"]) || 0
    comment_count = parse_int(stats["commentCount"]) || 0

    engagement_rate =
      if view_count > 0 do
        Float.round((like_count + comment_count) / view_count * 100, 2)
      else
        0.0
      end

    %{
      id: item["id"],
      title: snippet["title"],
      channel_title: snippet["channelTitle"],
      channel_id: snippet["channelId"],
      published_at: snippet["publishedAt"],
      thumbnail_url: get_in(snippet, ["thumbnails", "high", "url"]),
      view_count: view_count,
      like_count: like_count,
      comment_count: comment_count,
      engagement_rate: engagement_rate
    }
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
