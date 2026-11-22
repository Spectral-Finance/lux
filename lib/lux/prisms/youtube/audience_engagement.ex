defmodule Lux.Prisms.YouTube.AudienceEngagement do
  @moduledoc """
  A prism that analyses audience engagement quality across a channel's videos
  (lux issue #71 — "Audience engagement", "Retention signals", "Community health").

  Pure and deterministic: given a batch of raw `videos.list` items it computes
  engagement distribution statistics (mean/median/stdev of engagement rate),
  identifies the most and least engaging videos, classifies overall audience
  health, and surfaces actionable diagnostics. No network call is made here —
  callers fetch the videos via their YouTube client and pass them in, which
  keeps the prism unit-testable and side-effect free.

  ## Examples
      iex> AudienceEngagement.handler(%{
      ...>   videos: [
      ...>     %{"id" => "v1", "snippet" => %{"title" => "A"},
      ...>       "statistics" => %{"viewCount" => "1000", "likeCount" => "80", "commentCount" => "12"}}
      ...>   ]
      ...> }, %{})
      {:ok, %{health: :healthy, total_videos: 1, ...}}
  """

  use Lux.Prism,
    name: "YouTube Audience Engagement",
    description:
      "Analyses audience engagement quality and distribution across a channel's videos",
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
        total_videos: %{type: :integer, description: "Number of videos analysed"},
        avg_engagement_rate: %{type: :number, description: "Mean engagement rate"},
        median_engagement_rate: %{type: :number, description: "Median engagement rate"},
        engagement_stdev: %{type: :number, description: "Population stdev of engagement rate"},
        engagement_score: %{type: :number, description: "Overall engagement score (0-100)"},
        health: %{
          type: :string,
          description: ":excellent, :healthy, :developing, or :at_risk"
        },
        most_engaging: %{type: :object, description: "%{id, title, engagement_rate}"},
        least_engaging: %{type: :object, description: "%{id, title, engagement_rate}"},
        diagnostics: %{type: :array, description: "Actionable, human-readable findings"}
      },
      required: ["total_videos", "avg_engagement_rate", "engagement_score", "health"]
    }

  alias Lux.Prisms.YouTube.AnalyticsUtil

  def handler(params, _agent) do
    videos = AnalyticsUtil.fetch_key(params, :videos) || []
    metrics = AnalyticsUtil.metrics_batch(videos)

    rates = Enum.map(metrics, & &1.engagement_rate)
    avg_rate = AnalyticsUtil.mean(rates)
    median_rate = AnalyticsUtil.median(rates)
    stdev = AnalyticsUtil.stdev(rates)
    score = AnalyticsUtil.engagement_score(avg_rate)

    ranked =
      metrics |> Enum.sort_by(& &1.engagement_rate, :desc)

    result = %{
      total_videos: length(metrics),
      avg_engagement_rate: AnalyticsUtil.round_to(avg_rate, 6),
      median_engagement_rate: AnalyticsUtil.round_to(median_rate, 6),
      engagement_stdev: AnalyticsUtil.round_to(stdev, 6),
      engagement_score: AnalyticsUtil.round_to(score, 2),
      health: classify_health(score, length(metrics)),
      most_engaging: brief(List.first(ranked)),
      least_engaging: brief(List.last(ranked)),
      diagnostics: diagnostics(metrics, avg_rate, stdev)
    }

    {:ok, result}
  end

  defp brief(nil), do: %{}

  defp brief(m) do
    %{id: m.id, title: m.title, engagement_rate: AnalyticsUtil.round_to(m.engagement_rate, 6)}
  end

  defp classify_health(_score, 0), do: :at_risk
  defp classify_health(score, _n) when score >= 75, do: :excellent
  defp classify_health(score, _n) when score >= 45, do: :healthy
  defp classify_health(score, _n) when score >= 20, do: :developing
  defp classify_health(_score, _n), do: :at_risk

  defp diagnostics([], _avg, _stdev), do: ["No videos available to analyse."]

  defp diagnostics(metrics, avg_rate, stdev) do
    base = [
      consistency_note(stdev, avg_rate),
      format_note(metrics)
    ]

    base
    |> Enum.reject(&is_nil/1)
    |> Enum.concat(outlier_notes(metrics, avg_rate, stdev))
  end

  defp consistency_note(stdev, avg_rate) when avg_rate > 0 do
    cv = AnalyticsUtil.safe_div(stdev, avg_rate)

    cond do
      cv < 0.25 -> "Engagement is consistent across the catalogue (low variance)."
      cv > 0.75 -> "Engagement is highly variable — a few videos skew the average."
      true -> "Engagement shows moderate variance across videos."
    end
  end

  defp consistency_note(_stdev, _avg_rate), do: nil

  defp format_note(metrics) do
    with_durations = Enum.count(metrics, &(&1.duration_seconds > 0))

    if with_durations == 0 do
      nil
    else
      avg_len = metrics |> Enum.map(& &1.duration_seconds) |> AnalyticsUtil.mean()

      "Average video length is #{AnalyticsUtil.format_duration(round(avg_len))} across " <>
        "#{with_durations} videos with known duration."
    end
  end

  defp outlier_notes(metrics, avg_rate, stdev) do
    threshold = avg_rate + stdev

    metrics
    |> Enum.filter(&(&1.engagement_rate > threshold and stdev > 0))
    |> Enum.take(3)
    |> Enum.map(fn m ->
      "\"#{m.title}\" over-performs on engagement (#{
        AnalyticsUtil.round_to(m.engagement_rate, 4)
      }) — study its format."
    end)
  end
end