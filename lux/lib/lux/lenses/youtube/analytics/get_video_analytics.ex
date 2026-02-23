defmodule Lux.Lenses.YouTube.Analytics.GetVideoAnalytics do
  @moduledoc """
  A lens for retrieving detailed analytics for a YouTube video.

  Fetches video statistics, content details, and snippet from the YouTube
  Data API v3 /videos endpoint, then computes derived metrics such as
  engagement rate, estimated revenue potential, and performance score.

  ## Authentication

  Uses YouTube Data API key. Configure in application config:

      config :lux, :api_keys, youtube: "your_youtube_api_key"

  ## Examples

      iex> GetVideoAnalytics.focus(%{"video_id" => "dQw4w9WgXcQ"})
      {:ok, %{
        video_id: "dQw4w9WgXcQ",
        title: "Never Gonna Give You Up",
        view_count: 1_300_000_000,
        like_count: 15_000_000,
        comment_count: 2_500_000,
        engagement_rate: 1.15,
        performance_score: 95,
        duration: "PT3M33S"
      }}
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "Get Video Analytics",
    description: "Retrieves video performance metrics, statistics, and content details from YouTube Data API v3",
    url: "https://www.googleapis.com/youtube/v3/videos",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.api_key_auth(),
    schema: %{
      type: :object,
      properties: %{
        video_id: %{
          type: :string,
          description: "The YouTube video ID to retrieve analytics for"
        }
      },
      required: ["video_id"]
    }

  @doc """
  Builds the query parameters for the YouTube videos endpoint.
  """
  @impl true
  def before_focus(%{"video_id" => video_id} = _params) do
    {:ok, %{
      "part" => "statistics,contentDetails,snippet",
      "id" => video_id
    }}
  end

  @doc """
  Transforms the YouTube API response into analytics data with computed metrics.
  """
  @impl true
  def after_focus(%{"items" => [item | _]}) do
    stats = item["statistics"] || %{}
    snippet = item["snippet"] || %{}
    content = item["contentDetails"] || %{}

    view_count = parse_int(stats["viewCount"])
    like_count = parse_int(stats["likeCount"])
    comment_count = parse_int(stats["commentCount"])
    dislike_count = parse_int(stats["dislikeCount"])

    engagement_rate = compute_engagement_rate(like_count, comment_count, view_count)
    performance_score = compute_performance_score(view_count, engagement_rate)
    revenue_potential = estimate_revenue_potential(view_count)

    {:ok, %{
      video_id: item["id"],
      title: snippet["title"],
      description: snippet["description"],
      channel_id: snippet["channelId"],
      channel_title: snippet["channelTitle"],
      published_at: snippet["publishedAt"],
      tags: snippet["tags"] || [],
      category_id: snippet["categoryId"],
      view_count: view_count,
      like_count: like_count,
      dislike_count: dislike_count,
      comment_count: comment_count,
      favorite_count: parse_int(stats["favoriteCount"]),
      duration: content["duration"],
      definition: content["definition"],
      engagement_rate: engagement_rate,
      estimated_revenue_potential: revenue_potential,
      performance_score: performance_score
    }}
  end

  def after_focus(%{"items" => []}) do
    {:error, %{message: "Video not found", code: "VIDEO_NOT_FOUND"}}
  end

  def after_focus(%{"error" => %{"message" => message, "code" => code}}) do
    {:error, %{message: message, code: code}}
  end

  def after_focus(response) do
    {:error, %{message: "Unexpected response", detail: inspect(response)}}
  end

  defp parse_int(nil), do: 0
  defp parse_int(str) when is_binary(str), do: String.to_integer(str)
  defp parse_int(n) when is_integer(n), do: n

  defp compute_engagement_rate(_likes, _comments, 0), do: 0.0
  defp compute_engagement_rate(likes, comments, views) do
    Float.round((likes + comments) / views * 100, 2)
  end

  defp compute_performance_score(views, engagement_rate) do
    view_score = cond do
      views >= 10_000_000 -> 50
      views >= 1_000_000  -> 40
      views >= 100_000    -> 30
      views >= 10_000     -> 20
      views >= 1_000      -> 10
      true                -> 5
    end

    engagement_score = cond do
      engagement_rate >= 10.0 -> 50
      engagement_rate >= 5.0  -> 40
      engagement_rate >= 2.0  -> 30
      engagement_rate >= 1.0  -> 20
      engagement_rate >= 0.5  -> 10
      true                    -> 5
    end

    min(view_score + engagement_score, 100)
  end

  defp estimate_revenue_potential(views) do
    # Estimate based on ~$2 CPM (conservative)
    Float.round(views / 1000 * 2.0, 2)
  end
end
