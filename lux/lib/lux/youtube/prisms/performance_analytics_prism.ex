defmodule Lux.YouTube.Prisms.PerformanceAnalyticsPrism do
  @moduledoc """
  Analyzes video performance metrics and audience engagement for YouTube channels.
  NOTE: This is a deterministic heuristic baseline model, not a true ML prediction model.
  """
  use Lux.Prism,
    name: "PerformanceAnalyticsPrism",
    description: "Analyzes video performance and audience engagement data",
    input_schema: %{
      type: "object",
      properties: %{
        "video_data" => %{
          type: "array",
          items: %{
            type: "object",
            properties: %{
              "video_id" => %{type: "string"},
              "views" => %{type: "integer"},
              "watch_time_hours" => %{type: "number"},
              "ctr" => %{type: "number"},
              "avg_view_duration" => %{type: "number"}
            }
          },
          description: "List of video performance data objects"
        }
      },
      required: ["video_data"]
    },
    capabilities: ["analyze_video_performance", "analyze_audience_engagement"]

  def handler(%{"video_data" => video_data}, _context) do
    # Deterministic baseline model for performance analysis (not a true ML prediction)
    analysis =
      Enum.map(video_data, fn video ->
        ctr = normalize_bound(video["ctr"] || 0.0, 0.0, 100.0)
        views = max(video["views"] || 0, 0)
        watch_time = max(video["watch_time_hours"] || 0.0, 0.0)
        avg_view_duration = max(video["avg_view_duration"] || 0.0, 0.0)

        # Baseline scoring heuristic
        score =
          ctr * 10.0 +
            avg_view_duration * 0.5 +
            :math.log10(max(views, 1))

        performance_tier =
          cond do
            score > 50 -> "Excellent"
            score > 30 -> "Good"
            score > 15 -> "Average"
            true -> "Needs Improvement"
          end

        # estimated_retention assumes a 10-minute baseline video length to yield a percentage 0-100
        estimated_retention = normalize_bound((avg_view_duration / 10.0) * 100.0, 0.0, 100.0)

        %{
          video_id: video["video_id"],
          performance_score: Float.round(score, 4),
          performance_tier: performance_tier,
          engagement_metrics: %{
            estimated_retention: Float.round(estimated_retention, 2),
            audience_loyalty: Float.round(watch_time / max(views, 1), 4)
          }
        }
      end)

    {:ok, %{analysis_results: analysis, model: "deterministic_baseline_v1"}}
  end

  defp normalize_bound(value, min_val, max_val) do
    value |> max(min_val) |> min(max_val)
  end
end
