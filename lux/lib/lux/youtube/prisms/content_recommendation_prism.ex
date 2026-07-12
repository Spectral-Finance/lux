defmodule Lux.YouTube.Prisms.ContentRecommendationPrism do
  @moduledoc """
  Recommends content and analyzes trending topics on YouTube deterministically.
  NOTE: This is a deterministic heuristic baseline model, not a true ML prediction model.
  """
  use Lux.Prism,
    name: "ContentRecommendationPrism",
    description: "Recommends content ideas based on deterministic metrics",
    input_schema: %{
      type: "object",
      properties: %{
        "topics" => %{
          type: "array",
          items: %{type: "string"},
          description: "Candidate topics to evaluate"
        },
        "audience_segments" => %{
          type: "array",
          items: %{type: "string"},
          description: "Target audience segments"
        },
        "channel_metrics" => %{
          type: "object",
          description: "Channel performance baseline metrics",
          properties: %{
            "average_ctr" => %{type: "number"},
            "average_retention" => %{type: "number"}
          }
        }
      },
      required: ["topics", "audience_segments", "channel_metrics"]
    }

  def handler(input, _context) do
    topics = input[:topics] || input["topics"] || []
    metrics = input[:channel_metrics] || input["channel_metrics"] || %{}

    recommendations =
      topics
      |> Enum.map(&score_topic(&1, metrics, input))
      |> Enum.sort_by(& &1.score, :desc)

    {:ok, %{recommendations: recommendations, model: "deterministic_baseline_v1"}}
  end

  defp score_topic(topic, metrics, input) do
    ctr = normalize(metrics[:average_ctr] || metrics["average_ctr"] || 0.0, 0.0, 20.0)
    retention = normalize(metrics[:average_retention] || metrics["average_retention"] || 0.0, 0.0, 100.0)
    audience_fit = audience_fit(topic, input[:audience_segments] || input["audience_segments"] || [])

    score = Float.round(ctr * 0.35 + retention * 0.4 + audience_fit * 0.25, 4)

    %{
      topic: topic,
      score: score,
      confidence: confidence(score),
      rationale: "Ranked by CTR, retention, and audience-fit baseline"
    }
  end

  defp normalize(value, min, max) when max > min do
    value
    |> max(min)
    |> min(max)
    |> then(&((&1 - min) / (max - min)))
  end

  defp audience_fit(topic, segments) do
    topic_text = String.downcase(to_string(topic))

    if Enum.any?(segments, fn segment -> String.contains?(topic_text, String.downcase(to_string(segment))) end) do
      1.0
    else
      0.5
    end
  end

  defp confidence(score) when score >= 0.75, do: :high
  defp confidence(score) when score >= 0.5, do: :medium
  defp confidence(_), do: :low
end
