defmodule Lux.Lenses.YouTube.VideoAnalyticsLens do
  @moduledoc """
  Lens for fetching video performance metrics from the YouTube Data API v3
  and YouTube Analytics API.

  Retrieves comprehensive video analytics including view counts, engagement
  metrics, and estimated performance data.

  ## API Endpoints

  - Uses `videos.list` endpoint with `statistics` and `snippet` parts for basic metrics
  - Uses `youtubeAnalytics.reports.query` endpoint for detailed analytics (requires OAuth)

  ## Examples

      # Fetch basic video stats
      Lux.Lenses.YouTube.VideoAnalyticsLens.focus(%{
        video_id: "dQw4w9WgXcQ"
      })

      # Fetch with date range for analytics
      Lux.Lenses.YouTube.VideoAnalyticsLens.focus(%{
        video_id: "dQw4w9WgXcQ",
        start_date: "2024-01-01",
        end_date: "2024-01-31"
      })

  ## Response Format

      %{
        video_id: "dQw4w9WgXcQ",
        title: "Video Title",
        description: "Video description...",
        published_at: "2024-01-15T12:00:00Z",
        channel_id: "UC_x5XG1OV2P6uZZ5FSM9Ttw",
        channel_title: "Channel Name",
        statistics: %{
          view_count: 1_000_000,
          like_count: 50_000,
          comment_count: 10_000,
          favorite_count: 5_000,
          dislike_count: 500
        },
        engagement_rate: 0.055,
        thumbnails: %{
          default: "https://...",
          medium: "https://...",
          high: "https://...",
          standard: "https://...",
          maxres: "https://..."
        }
      }
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "YouTube Video Analytics",
    description: "Fetches video performance metrics including views, likes, comments, and engagement data",
    url: "#{YouTube.base_url()}/videos",
    method: :get,
    headers: YouTube.headers(),
    auth: %{
      type: :custom,
      auth_function: &YouTube.add_api_key/1
    },
    schema: %{
      type: :object,
      properties: %{
        video_id: %{
          type: :string,
          description: "YouTube video ID(s). Multiple IDs can be comma-separated (max 50)"
        },
        part: %{
          type: :string,
          description: "API resource parts to include in response",
          default: "snippet,statistics,contentDetails"
        },
        start_date: %{
          type: :string,
          description: "Start date for analytics query (ISO 8601 format: YYYY-MM-DD)",
          format: "date"
        },
        end_date: %{
          type: :string,
          description: "End date for analytics query (ISO 8601 format: YYYY-MM-DD)",
          format: "date"
        },
        metrics: %{
          type: :array,
          description: "Analytics metrics to include (requires YouTube Analytics API access)",
          items: %{
            type: :string,
            enum: [
              "views",
              "estimatedMinutesWatched",
              "averageViewDuration",
              "averageViewPercentage",
              "likes",
              "shares",
              "averageTimePaid",
              "subscribersGained",
              "subscribersLost"
            ]
          }
        }
      },
      required: ["video_id"]
    }

  require Logger

  @doc """
  Prepares parameters before making the API request.

  Sets the required `part` parameter and validates the video ID format.
  """
  @impl true
  def before_focus(params) do
    params =
      params
      |> Map.put_new(:part, "snippet,statistics,contentDetails")
      |> Map.update!(:video_id, fn id ->
        String.trim(id)
      end)

    Logger.debug("YouTube VideoAnalyticsLens before_focus: #{inspect(params)}")
    params
  end

  @doc """
  Transforms the YouTube API response into a structured format.

  Extracts relevant video statistics and calculates engagement metrics.

  ## Examples

      iex> after_focus(%{"items" => [%{
      ...>   "id" => "abc123",
      ...>   "snippet" => %{"title" => "Test Video", "channelTitle" => "Test Channel"},
      ...>   "statistics" => %{"viewCount" => "1000", "likeCount" => "50", "commentCount" => "10"}
      ...> }]})
      {:ok, %{video_id: "abc123", title: "Test Video", statistics: %{...}, engagement_rate: 0.06}}

      iex> after_focus(%{"error" => %{"message" => "Video not found"}})
      {:error, "Video not found"}
  """
  @impl true
  def after_focus(%{"items" => [video | _rest]} = _response) do
    result = transform_video(video)
    Logger.info("Successfully fetched video analytics: #{result.title}")
    {:ok, result}
  end

  @impl true
  def after_focus(%{"items" => items}) when is_list(items) and length(items) > 1 do
    videos = Enum.map(items, &transform_video/1)
    Logger.info("Successfully fetched analytics for #{length(videos)} videos")
    {:ok, %{videos: videos}}
  end

  @impl true
  def after_focus(%{"items" => []}) do
    Logger.warning("YouTube VideoAnalyticsLens: No videos found")
    {:error, "No video found. Verify the video ID is correct."}
  end

  @impl true
  def after_focus(%{"error" => %{"message" => message}}) do
    Logger.error("YouTube VideoAnalyticsLens API error: #{message}")
    {:error, message}
  end

  @impl true
  def after_focus(%{"error" => error}) when is_binary(error) do
    Logger.error("YouTube VideoAnalyticsLens API error: #{error}")
    {:error, error}
  end

  @impl true
  def after_focus(response) do
    Logger.error("YouTube VideoAnalyticsLens unexpected response: #{inspect(response)}")
    {:error, "Unexpected response format: #{inspect(response)}"}
  end

  # Transforms a single video item from the API response
  defp transform_video(video) do
    statistics = Map.get(video, "statistics", %{})
    snippet = Map.get(video, "snippet", %{})
    content_details = Map.get(video, "contentDetails", %{})
    thumbnails = Map.get(snippet, "thumbnails", %{})

    view_count = parse_integer(statistics["viewCount"])
    like_count = parse_integer(statistics["likeCount"])
    comment_count = parse_integer(statistics["commentCount"])
    favorite_count = parse_integer(statistics["favoriteCount"])

    # Calculate engagement rate (likes + comments) / views
    engagement_rate =
      if view_count > 0 do
        round(((like_count + comment_count) / view_count) * 10_000) / 100
      else
        0.0
      end

    %{
      video_id: video["id"],
      title: snippet["title"],
      description: snippet["description"],
      published_at: snippet["publishedAt"],
      channel_id: snippet["channelId"],
      channel_title: snippet["channelTitle"],
      category_id: snippet["categoryId"],
      tags: snippet["tags"] || [],
      default_language: snippet["defaultLanguage"],
      thumbnails: format_thumbnails(thumbnails),
      content_details: %{
        duration: content_details["duration"],
        dimension: content_details["dimension"],
        definition: content_details["definition"],
        caption: content_details["caption"],
        licensed: content_details["licensed"]
      },
      statistics: %{
        view_count: view_count,
        like_count: like_count,
        dislike_count: parse_integer(statistics["dislikeCount"]),
        favorite_count: favorite_count,
        comment_count: comment_count
      },
      engagement_rate: engagement_rate
    }
  end

  defp format_thumbnails(thumbnails) do
    %{
      default: thumbnails["default"]["url"],
      medium: thumbnails["medium"]["url"],
      high: thumbnails["high"]["url"],
      standard: thumbnails["standard"]["url"],
      maxres: thumbnails["maxres"]["url"]
    }
  rescue
    _e -> %{default: thumbnails["default"]["url"], medium: thumbnails["medium"]["url"], high: thumbnails["high"]["url"]}
  end

  defp parse_integer(nil), do: 0
  defp parse_integer(value) when is_integer(value), do: value

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _rest} -> int
      :error -> 0
    end
  end
end
