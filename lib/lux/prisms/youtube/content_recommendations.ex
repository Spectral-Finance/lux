defmodule Lux.Prisms.YouTube.ContentRecommendations do
  @moduledoc """
  A prism that generates data-driven content recommendations from a channel's
  historical performance (lux issue #71 — "Content intelligence",
  "Recommendations", "Programming strategy").

  Pure and deterministic: given a batch of raw `videos.list` items it clusters
  videos by title keyword, measures which topics over/under-perform relative to
  the channel median, and recommends what to make more of, what to retire, and
  the ideal length band. No network call and no opaque model — every
  recommendation is derived from transparent keyword aggregation so callers can
  audit the reasoning.

  ## Examples
      iex> ContentRecommendations.handler(%{
      ...>   videos: [
      ...>     %{"id" => "v1", "snippet" => %{"title" => "Sourdough baking guide", "publishedAt" => "2026-01-01T00:00:00Z"},
      ...>       "statistics" => %{"viewCount" => "20000", "likeCount" => "900", "commentCount" => "80"},
      ...>       "contentDetails" => %{"duration" => "PT10M"}}
      ...>   ]
      ...> }, %{})
      {:ok, %{double_down: [...], retire: [...], ...}}
  """

  use Lux.Prism,
    name: "YouTube Content Recommendations",
    description:
      "Generates data-driven content strategy recommendations from channel performance history",
    input_schema: %{
      type: :object,
      properties: %{
        videos: %{
          type: :array,
          description: "List of raw videos.list items (atom- or string-keyed)",
          items: %{type: :object}
        }
      },
      required: ["videos"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        video_count: %{type: :integer, description: "Number of videos analysed"},
        median_views: %{type: :number, description: "Channel median views (baseline)"},
        double_down: %{
          type: :array,
          description: "Topics over-performing: [%{keyword, avg_views, lift, sample_size}]"
        },
        retire: %{
          type: :array,
          description: "Topics under-performing: [%{keyword, avg_views, lift, sample_size}]"
        },
        ideal_length: %{type: :string, description: "Best-performing duration band"},
        summary: %{type: :string, description: "Human-readable strategy summary"}
      },
      required: ["video_count", "double_down", "retire"]
    }

  alias Lux.Prisms.YouTube.AnalyticsUtil

  # Common English stopwords excluded from topic keywords.
  @stopwords MapSet.new(~w(
    a an the and or but of to in on for with your you my our is are was were be how what
    why when where which this that it its at by from as vs i we do does can will new
  ))

  @min_topic_samples 2

  def handler(params, _agent) do
    videos = AnalyticsUtil.fetch_key(params, :videos) || []
    metrics = AnalyticsUtil.metrics_batch(videos)
    median_views = AnalyticsUtil.median(Enum.map(metrics, & &1.views))

    topics = topic_stats(metrics, median_views)

    {double_down, retire} =
      topics
      |> Enum.filter(&(&1.sample_size >= @min_topic_samples))
      |> Enum.split_with(&(&1.lift >= 1.0))

    double_down = double_down |> Enum.sort_by(& &1.lift, :desc) |> Enum.take(5)
    retire = retire |> Enum.sort_by(& &1.lift, :asc) |> Enum.take(5)

    result = %{
      video_count: length(metrics),
      median_views: AnalyticsUtil.round_to(median_views, 2),
      double_down: double_down,
      retire: retire,
      ideal_length: ideal_length(metrics),
      summary: summary(length(metrics), double_down, retire)
    }

    {:ok, result}
  end

  # Aggregate per-keyword view stats across the catalogue. `lift` is the mean
  # views for videos carrying the keyword divided by the channel median, so
  # lift > 1.0 means the topic over-performs the channel baseline.
  defp topic_stats(metrics, median_views) do
    metrics
    |> Enum.flat_map(fn m ->
      m.title
      |> keywords()
      |> Enum.map(fn kw -> {kw, m.views} end)
    end)
    |> Enum.group_by(fn {kw, _views} -> kw end, fn {_kw, views} -> views end)
    |> Enum.map(fn {kw, views} ->
      avg = AnalyticsUtil.mean(views)
      lift = if median_views > 0, do: avg / median_views, else: 1.0

      %{
        keyword: kw,
        avg_views: AnalyticsUtil.round_to(avg, 2),
        lift: AnalyticsUtil.round_to(lift, 3),
        sample_size: length(views)
      }
    end)
  end

  defp keywords(title) do
    title
    |> String.downcase()
    |> String.split(~r/[^a-z0-9]+/, trim: true)
    |> Enum.reject(&MapSet.member?(@stopwords, &1))
    |> Enum.reject(&(String.length(&1) < 3))
    |> Enum.uniq()
  end

  defp ideal_length([]), do: "No videos with duration data."

  defp ideal_length(metrics) do
    with_duration = Enum.filter(metrics, &(&1.duration_seconds > 0))

    if with_duration == [] do
      "No videos with duration data."
    else
      best =
        with_duration
        |> Enum.group_by(&band(&1.duration_seconds))
        |> Enum.map(fn {band, group} ->
          %{band: band, avg_views: AnalyticsUtil.mean(Enum.map(group, & &1.views))}
        end)
        |> Enum.sort_by(& &1.avg_views, :desc)
        |> List.first()

      "The #{best.band} band performs best (avg #{AnalyticsUtil.compact(round(best.avg_views))} views)."
    end
  end

  defp band(seconds) when seconds < 300, do: "under-5-min"
  defp band(seconds) when seconds < 600, do: "5-10-min"
  defp band(seconds) when seconds < 1200, do: "10-20-min"
  defp band(_seconds), do: "20-min-plus"

  defp summary(0, _double, _retire), do: "No videos available to generate recommendations."

  defp summary(count, double_down, retire) do
    parts = ["Analysed #{count} videos."]

    parts =
      case List.first(double_down) do
        nil -> parts
        %{keyword: kw} -> parts ++ ["Double down on \"#{kw}\" content."]
      end

    parts =
      case List.last(retire) do
        nil -> parts
        %{keyword: kw} -> parts ++ ["Consider retiring \"#{kw}\" topics."]
      end

    Enum.join(parts, " ")
  end
end