defmodule Lux.Lenses.YouTube.Videos.ListChannelVideos do
  @moduledoc """
  A lens for listing videos from a YouTube channel using the Search API.

  Returns videos ordered by date with basic metadata.
  For detailed stats, use GetVideo with the returned video IDs.

  ## Authentication

  Uses optional API key via `key` query parameter. Configure in application config:

      config :lux, :api_keys, youtube_api_key: "your_api_key"

  ## Examples

      iex> ListChannelVideos.focus(%{
      ...>   channel_id: "UCxxxxxxxxxxxxxxxxxxxxxx",
      ...>   max_results: 10
      ...> })
      {:ok, %{
        videos: [
          %{
            video_id: "abc123",
            title: "My Latest Video",
            description: "Video description...",
            published_at: "2024-01-15T12:00:00.000Z",
            thumbnail_url: "https://i.ytimg.com/vi/abc123/hqdefault.jpg"
          }
        ],
        next_page_token: "xyz...",
        total_results: 342
      }}
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "List YouTube Channel Videos",
    description: "Lists videos from a YouTube channel ordered by date",
    url: "https://www.googleapis.com/youtube/v3/search",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.api_key_auth(),
    schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The YouTube channel ID"
        },
        max_results: %{
          type: :integer,
          description: "Maximum number of results (1-50, default 20)",
          minimum: 1,
          maximum: 50,
          default: 20
        },
        page_token: %{
          type: :string,
          description: "Pagination token from previous response"
        },
        order: %{
          type: :string,
          description: "Sort order",
          enum: ["date", "rating", "relevance", "title", "viewCount"],
          default: "date"
        },
        event_type: %{
          type: :string,
          description: "Filter by broadcast type",
          enum: ["completed", "live", "upcoming"]
        }
      },
      required: ["channel_id"]
    }

  @impl true
  def before_focus(params) do
    channel_id = params["channel_id"] || params[:channel_id]
    max_results = params["max_results"] || params[:max_results] || 20
    order = params["order"] || params[:order] || "date"

    query = %{
      "channelId" => channel_id,
      "part" => "snippet",
      "type" => "video",
      "maxResults" => max_results,
      "order" => order
    }

    query =
      if page_token = params["page_token"] || params[:page_token] do
        Map.put(query, "pageToken", page_token)
      else
        query
      end

    query =
      if event_type = params["event_type"] || params[:event_type] do
        Map.put(query, "eventType", event_type)
      else
        query
      end

    {:ok, query}
  end

  @impl true
  def after_focus(%{"items" => items} = data) do
    page_info = data["pageInfo"] || %{}

    videos = Enum.map(items, fn item ->
      snippet = item["snippet"] || %{}
      video_id = get_in(item, ["id", "videoId"])

      %{
        video_id: video_id,
        title: snippet["title"],
        description: snippet["description"],
        channel_id: snippet["channelId"],
        channel_title: snippet["channelTitle"],
        published_at: snippet["publishedAt"],
        thumbnail_url: get_in(snippet, ["thumbnails", "high", "url"]),
        live_broadcast_content: snippet["liveBroadcastContent"]
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()
    end)

    {:ok, %{
      videos: videos,
      next_page_token: data["nextPageToken"],
      prev_page_token: data["prevPageToken"],
      total_results: page_info["totalResults"],
      results_per_page: page_info["resultsPerPage"]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()}
  end

  def after_focus(%{"error" => %{"message" => msg}}) do
    {:error, %{message: msg}}
  end

  def after_focus(response) do
    {:error, %{title: "Unexpected response", detail: inspect(response)}}
  end
end
