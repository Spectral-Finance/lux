defmodule Lux.Prisms.YouTube.PostingTimeOptimizer do
  @moduledoc """
  A prism that recommends optimal publishing times from a channel's historical
  performance (lux issue #71 — "Optimal posting times", "Audience timing",
  "Growth optimization").

  Pure and deterministic: given a batch of raw `videos.list` items it buckets
  each video by day-of-week and hour-of-day (UTC), computes the mean views per
  bucket, and recommends the top-performing slots. No network call is made here
  — callers fetch the videos via their YouTube client and pass them in, which
  keeps the prism unit-testable and side-effect free.

  ## Examples
      iex> PostingTimeOptimizer.handler(%{
      ...>   videos: [
      ...>     %{"id" => "v1", "snippet" => %{"title" => "A", "publishedAt" => "2026-01-06T18:00:00Z"},
      ...>       "statistics" => %{"viewCount" => "5000", "likeCount" => "200", "commentCount" => "20"}}
      ...>   ]
      ...> }, %{})
      {:ok, %{recommendations: [...], sample_size: 1}}
  """

  use Lux.Prism,
    name: "YouTube Posting Time Optimizer",
    description:
      "Recommends optimal publishing day/hour slots from a channel's historical view performance",
    input_schema: %{
      type: :object,
      properties: %{
        videos: %{
          type: :array,
          description: "List of raw videos.list items with snippet.publishedAt set",
          items: %{type: :object}
        },
        top_n: %{type: :integer, description: "Number of recommended slots (default 3)"}
      },
      required: ["videos"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        sample_size: %{type: :integer, description: "Number of videos with a usable publish date"},
        recommendations: %{
          type: :array,
          description: "Top slots: [%{day_of_week, hour_utc, avg_views, sample_size}]"
        },
        best_slot: %{type: :object, description: "The single best day/hour slot"},
        summary: %{type: :string, description: "Human-readable recommendation"}
      },
      required: ["sample_size", "recommendations"]
    }

  alias Lux.Prisms.YouTube.AnalyticsUtil

  @day_names ~w(Monday Tuesday Wednesday Thursday Friday Saturday Sunday)
  @default_top_n 3

  def handler(params, _agent) do
    videos = AnalyticsUtil.fetch_key(params, :videos) || []
    top_n = AnalyticsUtil.fetch_key(params, :top_n) || @default_top_n

    buckets =
      videos
      |> Enum.map(&AnalyticsUtil.video_metrics/1)
      |> Enum.map(fn m ->
        case AnalyticsUtil.parse_timestamp(m.published_at) do
          nil -> nil
          epoch -> slot_for(epoch, m.views)
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.group_by(& &1.slot)
      |> Enum.map(fn {slot, entries} ->
        views = Enum.map(entries, & &1.views)
        {dow, hour} = slot

        %{
          day_of_week: Enum.at(@day_names, dow - 1),
          day_index: dow,
          hour_utc: hour,
          avg_views: AnalyticsUtil.round_to(AnalyticsUtil.mean(views), 2),
          sample_size: length(views)
        }
      end)
      |> Enum.sort_by(& &1.avg_views, :desc)

    recommendations = Enum.take(buckets, max(1, top_n))

    result = %{
      sample_size: buckets |> Enum.map(& &1.sample_size) |> Enum.sum(),
      recommendations: recommendations,
      best_slot: List.first(recommendations) || %{},
      summary: summary(recommendations, videos)
    }

    {:ok, result}
  end

  # Date.day_of_week/1 -> 1=Mon..7=Sun; hour is UTC from the epoch.
  defp slot_for(epoch, views) do
    dt = DateTime.from_unix!(epoch, :second)
    dow = Date.day_of_week(DateTime.to_date(dt))
    %{slot: {dow, dt.hour}, views: views}
  end

  defp summary([], _videos), do: "Not enough dated videos to recommend a posting time."

  defp summary([best | _], videos) do
    "Across #{length(videos)} videos, the strongest slot is #{best.day_of_week} at " <>
      "#{pad(best.hour_utc)}:00 UTC (avg #{AnalyticsUtil.compact(round(best.avg_views))} views)."
  end

  defp pad(n), do: n |> Integer.to_string() |> String.pad_leading(2, "0")
end