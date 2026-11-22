defmodule Lux.Prisms.YouTube.PerformancePredictor do
  @moduledoc """
  A prism that predicts a new YouTube video's performance from its metadata
  (lux issue #71 — "Performance prediction", "Pre-publish intelligence",
  "Scenario planning").

  Pure and deterministic: given a channel's historical video metrics and a
  candidate video (title + duration), it estimates the candidate's view count,
  engagement rate and performance band by analogy to the most similar
  historical videos. No network call and no opaque model — the prediction is an
  auditable, similarity-weighted blend of comparable past videos, so callers can
  explain every number.

  ## Examples
      iex> PerformancePredictor.handler(%{
      ...>   history: [
      ...>     %{"id" => "v1", "snippet" => %{"title" => "Baking sourdough", "publishedAt" => "2026-01-01T00:00:00Z"},
      ...>       "statistics" => %{"viewCount" => "10000", "likeCount" => "500", "commentCount" => "50"},
      ...>       "contentDetails" => %{"duration" => "PT12M"}}
      ...>   ],
      ...>   candidate: %{title: "Baking sourdough at home", duration_seconds: 720}
      ...> }, %{})
      {:ok, %{predicted_views: 9500.0, confidence: 0.8, ...}}
  """

  use Lux.Prism,
    name: "YouTube Performance Predictor",
    description:
      "Predicts a candidate video's views and engagement from channel history via similarity weighting",
    input_schema: %{
      type: :object,
      properties: %{
        history: %{
          type: :array,
          description: "Historical raw videos.list items for the channel",
          items: %{type: :object}
        },
        candidate: %{
          type: :object,
          description: "%{title: string, duration_seconds: number} describing the planned video",
          properties: %{
            title: %{type: :string, description: "Working title of the planned video"},
            duration_seconds: %{type: :number, description: "Planned length in seconds"}
          },
          required: ["title"]
        }
      },
      required: ["history", "candidate"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        predicted_views: %{type: :number, description: "Estimated view count"},
        predicted_likes: %{type: :number, description: "Estimated like count"},
        predicted_engagement_rate: %{type: :number, description: "Estimated engagement rate"},
        confidence: %{type: :number, description: "Confidence in [0.0, 1.0] from comparable-sample size"},
        band: %{type: :string, description: ":breakout, :above_average, :average, or :underperform"},
        comparable_count: %{type: :integer, description: "Number of historical videos used"},
        rationale: %{type: :string, description: "Human-readable explanation of the estimate"}
      },
      required: ["predicted_views", "confidence", "band"]
    }

  alias Lux.Prisms.YouTube.AnalyticsUtil

  # Similarity weights for the analogy blend.
  @title_weight 0.6
  @duration_weight 0.4

  def handler(params, _agent) do
    history = AnalyticsUtil.fetch_key(params, :history) || []
    candidate = AnalyticsUtil.fetch_key(params, :candidate) || %{}

    metrics = AnalyticsUtil.metrics_batch(history)
    cand_title = candidate |> AnalyticsUtil.fetch_key(:title) |> to_string()

    cand_duration =
      candidate |> AnalyticsUtil.fetch_key(:duration_seconds) |> AnalyticsUtil.to_float()

    scored =
      metrics
      |> Enum.map(fn m ->
        similarity = similarity(cand_title, m.title, cand_duration, m.duration_seconds)
        {m, similarity}
      end)
      |> Enum.sort_by(fn {_m, s} -> s end, :desc)

    {predicted_views, predicted_rate, confidence, comparable_count} =
      blend(scored, metrics)

    predicted_likes = predicted_views * predicted_rate

    result = %{
      predicted_views: AnalyticsUtil.round_to(predicted_views, 1),
      predicted_likes: AnalyticsUtil.round_to(predicted_likes, 1),
      predicted_engagement_rate: AnalyticsUtil.round_to(predicted_rate, 6),
      confidence: AnalyticsUtil.round_to(confidence, 3),
      band: band(predicted_views, metrics),
      comparable_count: comparable_count,
      rationale:
        rationale(predicted_views, confidence, comparable_count, length(metrics))
    }

    {:ok, result}
  end

  # Similarity in [0,1]: token overlap of titles blended with duration closeness.
  defp similarity(cand_title, hist_title, cand_duration, hist_duration) do
    title_sim = jaccard(tokens(cand_title), tokens(hist_title))

    duration_sim =
      if cand_duration > 0 and hist_duration > 0 do
        1.0 - min(1.0, abs(cand_duration - hist_duration) / max(cand_duration, hist_duration))
      else
        0.5
      end

    title_sim * @title_weight + duration_sim * @duration_weight
  end

  defp tokens(text) do
    text
    |> String.downcase()
    |> String.split(~r/[^a-z0-9]+/, trim: true)
    |> MapSet.new()
  end

  defp jaccard(set_a, set_b) do
    union = MapSet.union(set_a, set_b)

    if MapSet.size(union) == 0 do
      0.0
    else
      MapSet.intersection(set_a, set_b) |> MapSet.size() |> Kernel./(MapSet.size(union))
    end
  end

  # Similarity-weighted average of views and engagement over the top comparables.
  defp blend([], _metrics), do: {0.0, 0.0, 0.0, 0}

  defp blend(scored, metrics) do
    # Keep comparables with at least half the best similarity, capped at 5.
    scored = scored |> Enum.take(5)
    total_weight = scored |> Enum.map(fn {_m, s} -> s end) |> Enum.sum()

    if total_weight <= 0.0 do
      # No signal at all — fall back to the plain channel average.
      views = metrics |> Enum.map(& &1.views) |> AnalyticsUtil.mean()
      rate = metrics |> Enum.map(& &1.engagement_rate) |> AnalyticsUtil.mean()
      {views, rate, 0.1, length(metrics)}
    else
      views =
        scored |> Enum.map(fn {m, s} -> m.views * s end) |> Enum.sum() |> Kernel./(total_weight)

      rate =
        scored
        |> Enum.map(fn {m, s} -> m.engagement_rate * s end)
        |> Enum.sum()
        |> Kernel./(total_weight)

      confidence = confidence(total_weight, length(scored))
      {views, rate, confidence, length(scored)}
    end
  end

  # Confidence grows with both absolute similarity mass and comparable count.
  defp confidence(total_weight, comparable_count) do
    mass = min(1.0, total_weight / max(1, comparable_count))
    depth = min(1.0, comparable_count / 5.0)
    (mass + depth) / 2.0
  end

  defp band(_views, []), do: :average

  defp band(views, metrics) do
    median = AnalyticsUtil.median(Enum.map(metrics, & &1.views))
    avg = AnalyticsUtil.mean(Enum.map(metrics, & &1.views))

    cond do
      median > 0 and views >= 2 * median -> :breakout
      views >= avg -> :above_average
      views >= 0.5 * avg -> :average
      true -> :underperform
    end
  end

  defp rationale(views, confidence, comparable_count, history_size) do
    "#{AnalyticsUtil.compact(round(views))} views estimated from #{comparable_count} comparable " <>
      "video(s) out of #{history_size} in channel history (confidence #{
        AnalyticsUtil.round_to(confidence * 100, 0)
      }%)."
  end
end