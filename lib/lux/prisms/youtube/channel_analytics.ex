defmodule Lux.Prisms.YouTube.ChannelAnalytics do
  @moduledoc """
  A prism that computes channel-level analytics from a batch of YouTube videos
  (lux issue #71 — "Channel analytics", "Performance metrics", "Growth tracking").

  Pure and deterministic: given a list of raw `videos.list` items (as returned
  by `videos.list` for a channel's uploads playlist) it produces aggregate
  performance metrics — total views/likes/comments, averages, medians,
  engagement rate and score, upload cadence and a top-video breakdown. No
  network call is made here — callers fetch the videos via their YouTube client
  and pass them in, which keeps the prism unit-testable and side-effect free.

  ## Examples
      iex> ChannelAnalytics.handler(%{
      ...>   videos: [
      ...>     %{"id" => "v1", "snippet" => %{"title" => "A", "publishedAt" => "2026-01-01T00:00:00Z"},
      ...>       "statistics" => %{"viewCount" => "1000", "likeCount" => "50", "commentCount" => "5"}}
      ...>   ]
      ...> }, %{})
      {:ok, %{total_views: 1000, video_count: 1, ...}}
  """

  use Lux.Prism,
    name: "YouTube Channel Analytics",
    description:
      "Computes aggregate channel performance metrics from a batch of YouTube videos",
    input_schema: %{
      type: :object,
      properties: %{
        videos: %{
          type: :array,
          description: "List of raw videos.list items (atom- or string-keyed)",
          items: %{type: :object}
        },
        channel_title: %{type: :string, description: "Optional channel title for the report"}
      },
      required: ["videos"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        channel_title: %{type: :string, description: "Channel title (if provided)"},
        video_count: %{type: :integer, description: "Number of videos analyzed"},
        total_views: %{type: :integer, description: "Sum of views across all videos"},
        total_likes: %{type: :integer, description: "Sum of likes across all videos"},
        total_comments: %{type: :integer, description: "Sum of comments across all videos"},
        avg_views: %{type: :number, description: "Mean views per video"},
        median_views: %{type: :number, description: "Median views per video"},
        avg_engagement_rate: %{type: :number, description: "Mean engagement rate"},
        engagement_score: %{type: :number, description: "Channel engagement score (0-100)"},
        top_videos: %{
          type: :array,
          description: "Top 5 videos by views: [%{id, title, views, engagement_score}]"
        },
        upload_cadence: %{type: :string, description: "Human-readable upload cadence summary"}
      },
      required: ["video_count", "total_views", "avg_views", "engagement_score"]
    }

  alias Lux.Prisms.YouTube.AnalyticsUtil

  @top_n 5

  def handler(params, _agent) do
    videos = AnalyticsUtil.fetch_key(params, :videos) || []
    channel_title = AnalyticsUtil.fetch_key(params, :channel_title)

    metrics = AnalyticsUtil.metrics_batch(videos)
    views_list = Enum.map(metrics, & &1.views)

    total_views = Enum.sum(views_list)
    total_likes = metrics |> Enum.map(& &1.likes) |> Enum.sum()
    total_comments = metrics |> Enum.map(& &1.comments) |> Enum.sum()

    avg_views = AnalyticsUtil.mean(views_list)
    median_views = AnalyticsUtil.median(views_list)

    avg_engagement_rate =
      metrics |> Enum.map(& &1.engagement_rate) |> AnalyticsUtil.mean()

    engagement_score = AnalyticsUtil.engagement_score(avg_engagement_rate)

    top_videos =
      metrics
      |> Enum.sort_by(& &1.views, :desc)
      |> Enum.take(@top_n)
      |> Enum.map(fn m ->
        %{
          id: m.id,
          title: m.title,
          views: m.views,
          engagement_score: m.engagement_score
        }
      end)

    result = %{
      channel_title: channel_title || "",
      video_count: length(metrics),
      total_views: total_views,
      total_likes: total_likes,
      total_comments: total_comments,
      avg_views: AnalyticsUtil.round_to(avg_views, 2),
      median_views: AnalyticsUtil.round_to(median_views, 2),
      avg_engagement_rate: AnalyticsUtil.round_to(avg_engagement_rate, 6),
      engagement_score: AnalyticsUtil.round_to(engagement_score, 2),
      top_videos: top_videos,
      upload_cadence: cadence_summary(metrics)
    }

    {:ok, result}
  end

  defp cadence_summary([]), do: "No videos to analyze."

  defp cadence_summary(metrics) do
    dates =
      metrics
      |> Enum.map(&AnalyticsUtil.parse_timestamp(&1.published_at))
      |> Enum.reject(&is_nil/1)
      |> Enum.sort()

    case dates do
      [] ->
        "Upload dates unavailable."

      [single] ->
        "1 video published."

      [first | _] = all ->
        span_days = (List.last(all) - first) / 86400.0
        per_week = AnalyticsUtil.safe_div(length(all), span_days) * 7.0
        "Published #{length(all)} videos over #{Float.round(span_days, 1)} days (~#{Float.round(per_week, 1)}/week)."
    end
  end
end