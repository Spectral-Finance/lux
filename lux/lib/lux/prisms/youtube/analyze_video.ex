defmodule Lux.Prisms.YouTube.AnalyzeVideo do
  @moduledoc """
  A prism that computes derived performance metrics for a YouTube video from
  a raw `videos.list` item (lux issue #69 — "Analytics data collection and
  processing").

  Pure and deterministic: given the snippet/statistics/contentDetails maps
  (as returned by the YouTube Data API v3), it returns engagement rate, like
  ratio, comment ratio, parsed duration, and a 0-100 engagement score. No
  network call is made here — callers fetch the item via their YouTube client
  and pass it in, which keeps the prism unit-testable and side-effect free.

  ## Examples
      iex> AnalyzeVideo.handler(%{
      ...>   id: "abc123",
      ...>   snippet: %{"title" => "My Video", "publishedAt" => "2026-01-01T12:00:00Z"},
      ...>   statistics: %{"viewCount" => "1000", "likeCount" => "50", "commentCount" => "10"},
      ...>   contentDetails: %{"duration" => "PT1H2M3S"}
      ...> }, %{name: "Agent"})
      {:ok, %{video_id: "abc123", views: 1000, likes: 50, comments: 10,
             engagement_rate: 0.06, duration_seconds: 3723.0}}
  """

  use Lux.Prism,
    name: "Analyze YouTube Video",
    description: "Computes engagement metrics for a YouTube video from a videos.list item",
    input_schema: %{
      type: :object,
      properties: %{
        id: %{type: :string, description: "The video ID"},
        snippet: %{type: :object, description: "videos.list snippet (title, publishedAt)"},
        statistics: %{
          type: :object,
          description: "videos.list statistics (viewCount, likeCount, commentCount)"
        },
        contentDetails: %{
          type: :object,
          description: "videos.list contentDetails (ISO-8601 duration)"
        }
      },
      required: ["id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        video_id: %{type: :string, description: "The video ID"},
        title: %{type: :string, description: "The video title"},
        views: %{type: :integer, description: "View count"},
        likes: %{type: :integer, description: "Like count"},
        comments: %{type: :integer, description: "Comment count"},
        engagement_rate: %{type: :number, description: "(likes + comments) / views"},
        like_ratio: %{type: :number, description: "likes / views"},
        comment_ratio: %{type: :number, description: "comments / views"},
        engagement_score: %{type: :number, description: "0-100 score (4% engagement = 100)"},
        duration_seconds: %{type: :number, description: "Parsed video duration in seconds"},
        published_at: %{type: :string, description: "ISO-8601 publish time"}
      },
      required: ["video_id", "views", "engagement_rate"]
    }

  alias Lux.Prisms.YouTube.Util

  def handler(params, _agent) do
    snippet = Map.get(params, :snippet, %{})
    stats = Map.get(params, :statistics, %{})
    content = Map.get(params, :contentDetails, %{})

    views = to_int(Map.get(stats, "viewCount"))
    likes = to_int(Map.get(stats, "likeCount"))
    comments = to_int(Map.get(stats, "commentCount"))
    duration = Util.parse_iso8601_duration(Map.get(content, "duration", ""))

    engagement_rate = Util.safe_div(likes + comments, views)

    result = %{
      video_id: Map.get(params, :id, ""),
      title: Map.get(snippet, "title", ""),
      views: views,
      likes: likes,
      comments: comments,
      engagement_rate: round(engagement_rate * 10_000) / 10_000,
      like_ratio: round(Util.safe_div(likes, views) * 10_000) / 10_000,
      comment_ratio: round(Util.safe_div(comments, views) * 10_000) / 10_000,
      engagement_score: round(Util.engagement_score(engagement_rate) * 10) / 10,
      duration_seconds: duration,
      published_at: Map.get(snippet, "publishedAt", "")
    }

    {:ok, result}
  end

  defp to_int(nil), do: 0
  defp to_int(value) when is_integer(value), do: value

  defp to_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {n, _} -> n
      :error -> 0
    end
  end

  defp to_int(_), do: 0
end