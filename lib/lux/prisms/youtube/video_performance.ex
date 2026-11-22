defmodule Lux.Prisms.YouTube.VideoPerformance do
  @moduledoc """
  A prism that scores and ranks individual YouTube videos by performance
  (lux issue #71 — "Video performance", "Content intelligence", "Benchmarking").

  Pure and deterministic: given a batch of raw `videos.list` items it computes a
  normalised 0-100 performance score per video (blending views, engagement and
  velocity), ranks them, and flags statistical outliers vs. the channel median.
  No network call is made here — callers fetch the videos via their YouTube
  client and pass them in, which keeps the prism unit-testable and side-effect
  free.

  ## Examples
      iex> VideoPerformance.handler(%{
      ...>   videos: [
      ...>     %{"id" => "v1", "snippet" => %{"title" => "A", "publishedAt" => "2026-01-01T00:00:00Z"},
      ...>       "statistics" => %{"viewCount" => "1000", "likeCount" => "80", "commentCount" => "10"}}
      ...>   ]
      ...> }, %{})
      {:ok, %{ranked: [...], count: 1}}
  """

  use Lux.Prism,
    name: "YouTube Video Performance",
    description:
      "Scores and ranks YouTube videos by a blended views/engagement/velocity performance metric",
    input_schema: %{
      type: :object,
      properties: %{
        videos: %{
          type: :array,
          description: "List of raw videos.list items (atom- or string-keyed)",
          items: %{type: :object}
        },
        now_epoch: %{type: :integer, description: "Override 'now' (Unix epoch) for velocity calc"}
      },
      required: ["videos"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        count: %{type: :integer, description: "Number of videos scored"},
        ranked: %{
          type: :array,
          description: "Videos sorted by performance_score desc: [%{id, title, views, performance_score, outlier}]"
        },
        median_views: %{type: :number, description: "Channel median views (outlier baseline)"},
        top_performer: %{type: :string, description: "Title of the highest-scoring video"}
      },
      required: ["count", "ranked"]
    }

  alias Lux.Prisms.YouTube.AnalyticsUtil

  def handler(params, _agent) do
    videos = AnalyticsUtil.fetch_key(params, :videos) || []
    now_epoch = AnalyticsUtil.fetch_key(params, :now_epoch) || System.system_time(:second)

    metrics = AnalyticsUtil.metrics_batch(videos)
    median_views = AnalyticsUtil.median(Enum.map(metrics, & &1.views))

    scored =
      metrics
      |> Enum.map(fn m ->
        velocity = velocity_per_day(m, now_epoch)
        score = performance_score(m, median_views, velocity)

        %{
          id: m.id,
          title: m.title,
          views: m.views,
          likes: m.likes,
          comments: m.comments,
          engagement_score: m.engagement_score,
          velocity_per_day: AnalyticsUtil.round_to(velocity, 2),
          performance_score: AnalyticsUtil.round_to(score, 2),
          outlier: outlier?(m.views, median_views)
        }
      end)
      |> Enum.sort_by(& &1.performance_score, :desc)

    result = %{
      count: length(scored),
      ranked: scored,
      median_views: AnalyticsUtil.round_to(median_views, 2),
      top_performer: scored |> List.first(%{}) |> Map.get(:title, "")
    }

    {:ok, result}
  end

  # Views-per-day since publish, 0.0 when the publish date is unknown.
  defp velocity_per_day(metrics, now_epoch) do
    age = AnalyticsUtil.age_days(metrics.published_at, now_epoch)
    if age > 0.0, do: metrics.views / age, else: 0.0
  end

  # Blend: 60% engagement score, 40% relative-views score (views vs 2x median).
  defp performance_score(metrics, median_views, _velocity) do
    views_component =
      metrics.views
      |> relative_views(median_views)
      |> AnalyticsUtil.engagement_score()

    metrics.engagement_score * 0.6 + views_component * 0.4
  end

  defp relative_views(views, median) when median <= 0, do: AnalyticsUtil.safe_div(views, 1)
  defp relative_views(views, median), do: AnalyticsUtil.safe_div(views, median * 2.0)

  # A video is an outlier when it has >= 2x the median views (breakout hit).
  defp outlier?(views, median) when median > 0, do: views >= 2 * median
  defp outlier?(_views, _median), do: false
end