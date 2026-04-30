defmodule Lux.Prisms.YoutubeAnalytics.PerformanceBenchmarkPrism do
  @moduledoc """
  Prism for comparing channel performance against industry benchmarks.

  Provides percentile rankings, category comparisons, and performance
  gap analysis with actionable insights.
  """

  use Lux.Prism,
    name: "YouTube Performance Benchmark",
    description: "Compares channel performance against industry benchmarks and category averages",
    input_schema: %{
      type: :object,
      properties: %{
        channel_metrics: %{
          type: :object,
          properties: %{
            subscriber_count: %{type: :integer},
            view_count: %{type: :integer},
            video_count: %{type: :integer},
            avg_views_per_video: %{type: :float},
            engagement_rate: %{type: :float}
          },
          description: "Channel metrics to benchmark"
        },
        category: %{
          type: :string,
          description: "Video category for benchmark comparison",
          default: "general"
        },
        region: %{
          type: :string,
          description: "Geographic region",
          default: "global"
        }
      },
      required: ["channel_metrics"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        benchmarks: %{
          type: :object,
          properties: %{
            category_avg_views: %{type: :float},
            category_avg_engagement: %{type: :float},
            category_avg_subscribers: %{type: :integer}
          }
        },
        percentile_rankings: %{
          type: :object,
          properties: %{
            views_percentile: %{type: :integer},
            engagement_percentile: %{type: :integer},
            subscriber_percentile: %{type: :integer},
            overall_percentile: %{type: :integer}
          }
        },
        gaps: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              metric: %{type: :string},
              current: %{type: :float},
              benchmark: %{type: :float},
              gap_percentage: %{type: :float},
              status: %{type: :string}
            }
          }
        },
        strengths: %{type: :array, items: %{type: :string}},
        improvement_areas: %{type: :array, items: %{type: :string}}
      }
    }

  @doc """
  Benchmark channel performance against industry standards.
  """
  def transform(params) when is_map(params) do
    channel_metrics = Map.get(params, :channel_metrics, %{})
    category = Map.get(params, :category, "general")

    benchmarks = get_category_benchmarks(category)
    percentile_rankings = calculate_percentiles(channel_metrics, benchmarks)
    gaps = calculate_gaps(channel_metrics, benchmarks)
    strengths = identify_strengths(channel_metrics, benchmarks)
    improvement_areas = identify_improvements(channel_metrics, benchmarks)

    {:ok, %{
      benchmarks: benchmarks,
      percentile_rankings: percentile_rankings,
      gaps: gaps,
      strengths: strengths,
      improvement_areas: improvement_areas
    }}
  end

  defp get_category_benchmarks(category) do
    %{
      "general" => %{avg_views_per_video: 5000, avg_engagement_rate: 3.5, avg_subscribers: 10000},
      "technology" => %{avg_views_per_video: 8000, avg_engagement_rate: 4.0, avg_subscribers: 15000},
      "entertainment" => %{avg_views_per_video: 15000, avg_engagement_rate: 5.0, avg_subscribers: 50000},
      "education" => %{avg_views_per_video: 3000, avg_engagement_rate: 4.5, avg_subscribers: 8000},
      "gaming" => %{avg_views_per_video: 10000, avg_engagement_rate: 6.0, avg_subscribers: 25000},
      "finance" => %{avg_views_per_video: 6000, avg_engagement_rate: 3.0, avg_subscribers: 12000},
      "lifestyle" => %{avg_views_per_video: 7000, avg_engagement_rate: 4.0, avg_subscribers: 20000}
    } |> Map.get(category, Map.get(%{"general" => %{avg_views_per_video: 5000, avg_engagement_rate: 3.5, avg_subscribers: 10000}}, "general"))
  end

  defp calculate_percentiles(cm, benchmarks) do
    avg_views = cm.avg_views_per_video || 0
    avg_engagement = cm.engagement_rate || 0
    subs = cm.subscriber_count || 0

    %{
      views_percentile: percentile(avg_views, benchmarks.avg_views_per_video),
      engagement_percentile: percentile(avg_engagement, benchmarks.avg_engagement_rate),
      subscriber_percentile: percentile(subs, benchmarks.avg_subscribers),
      overall_percentile: 0
    } |> Map.put(:overall_percentile, fn m -> round((m.views_percentile + m.engagement_percentile + m.subscriber_percentile) / 3) end)
    |> then(fn m -> Map.put(m, :overall_percentile, round((m.views_percentile + m.engagement_percentile + m.subscriber_percentile) / 3)) end)
  end

  defp percentile(value, benchmark) when benchmark == 0, do: 50
  defp percentile(value, benchmark) do
    ratio = value / benchmark
    cond do
      ratio >= 2.0 -> 95
      ratio >= 1.5 -> 85
      ratio >= 1.2 -> 75
      ratio >= 1.0 -> 65
      ratio >= 0.8 -> 50
      ratio >= 0.5 -> 35
      ratio >= 0.3 -> 20
      true -> 10
    end
  end

  defp calculate_gaps(cm, benchmarks) do
    [
      build_gap("avg_views_per_video", cm.avg_views_per_video || 0, benchmarks.avg_views_per_video),
      build_gap("engagement_rate", cm.engagement_rate || 0, benchmarks.avg_engagement_rate),
      build_gap("subscriber_count", cm.subscriber_count || 0, benchmarks.avg_subscribers)
    ]
  end

  defp build_gap(metric, current, benchmark) do
    gap_pct = if benchmark > 0, do: Float.round(((current - benchmark) / benchmark) * 100, 1), else: 0.0
    status = cond do
      gap_pct >= 10 -> "above_benchmark"
      gap_pct >= -10 -> "at_benchmark"
      true -> "below_benchmark"
    end
    %{metric: metric, current: current, benchmark: benchmark, gap_percentage: gap_pct, status: status}
  end

  defp identify_strengths(cm, benchmarks) do
    strengths = []
    avg_views = cm.avg_views_per_video || 0
    strengths = if avg_views >= benchmarks.avg_views_per_video * 1.2, do: ["Views per video exceeds category average"] ++ strengths, else: strengths
    avg_engagement = cm.engagement_rate || 0
    strengths = if avg_engagement >= benchmarks.avg_engagement_rate * 1.2, do: ["Engagement rate exceeds category average"] ++ strengths, else: strengths
    strengths
  end

  defp identify_improvements(cm, benchmarks) do
    improvements = []
    avg_views = cm.avg_views_per_video || 0
    improvements = if avg_views < benchmarks.avg_views_per_video * 0.8, do: ["Increase views per video to reach category average"] ++ improvements, else: improvements
    avg_engagement = cm.engagement_rate || 0
    improvements = if avg_engagement < benchmarks.avg_engagement_rate * 0.8, do: ["Improve engagement through better CTAs"] ++ improvements, else: improvements
    improvements
  end
end
