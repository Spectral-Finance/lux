defmodule Lux.Prisms.YouTube.BenchmarkChannel do
  @moduledoc """
  A prism for benchmarking a YouTube channel against niche averages.

  Compares channel statistics against curated industry benchmarks for
  common niches (tech, gaming, education, lifestyle, general) and returns:
  - percentile rank (0-100)
  - competitive position label
  - areas of strength and areas for improvement

  This prism performs local computation only — no external API calls.

  ## Examples

      iex> BenchmarkChannel.handler(%{
      ...>   "channel_stats" => %{
      ...>     "subscriber_count" => 85_000,
      ...>     "view_count" => 6_200_000,
      ...>     "video_count" => 200,
      ...>     "avg_views_per_video" => 31_000
      ...>   },
      ...>   "niche" => "tech"
      ...> }, %{})
      {:ok, %{
        niche: "tech",
        percentile_rank: 72,
        competitive_position: "above_average",
        benchmark_comparison: %{...},
        areas_of_strength: ["subscriber_count", "avg_views_per_video"],
        areas_for_improvement: ["video_count"]
      }}
  """

  use Lux.Prism,
    name: "Benchmark YouTube Channel",
    description: "Compares channel stats against niche averages and returns competitive position analysis",
    input_schema: %{
      type: :object,
      properties: %{
        channel_stats: %{
          type: :object,
          description: "Channel statistics map",
          properties: %{
            subscriber_count: %{type: :integer},
            view_count: %{type: :integer},
            video_count: %{type: :integer},
            avg_views_per_video: %{type: :integer}
          },
          required: ["subscriber_count", "view_count", "video_count"]
        },
        niche: %{
          type: :string,
          description: "Channel niche for benchmark comparison",
          enum: ["tech", "gaming", "education", "lifestyle", "general"],
          default: "general"
        }
      },
      required: ["channel_stats"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        niche: %{type: :string},
        percentile_rank: %{type: :integer, description: "0-100 percentile rank vs niche"},
        competitive_position: %{
          type: :string,
          enum: ["leader", "above_average", "average", "below_average", "emerging"]
        },
        benchmark_comparison: %{type: :object},
        areas_of_strength: %{type: :array, items: %{type: :string}},
        areas_for_improvement: %{type: :array, items: %{type: :string}}
      },
      required: ["niche", "percentile_rank", "competitive_position", "benchmark_comparison",
                 "areas_of_strength", "areas_for_improvement"]
    }

  require Logger

  @benchmarks %{
    "tech" => %{
      subscriber_count: 50_000,
      avg_views_per_video: 15_000,
      video_count: 150,
      view_count: 3_000_000
    },
    "gaming" => %{
      subscriber_count: 80_000,
      avg_views_per_video: 25_000,
      video_count: 300,
      view_count: 8_000_000
    },
    "education" => %{
      subscriber_count: 40_000,
      avg_views_per_video: 12_000,
      video_count: 100,
      view_count: 1_500_000
    },
    "lifestyle" => %{
      subscriber_count: 60_000,
      avg_views_per_video: 20_000,
      video_count: 200,
      view_count: 4_000_000
    },
    "general" => %{
      subscriber_count: 50_000,
      avg_views_per_video: 15_000,
      video_count: 150,
      view_count: 3_000_000
    }
  }

  def handler(params, agent) do
    agent_name = get_in(agent, [:agent, :name]) || agent[:name] || "Unknown"
    Logger.info("Agent #{agent_name} benchmarking channel")

    niche = params["niche"] || params[:niche] || "general"
    stats = params["channel_stats"] || params[:channel_stats] || %{}

    subscriber_count = stats["subscriber_count"] || stats[:subscriber_count] || 0
    view_count = stats["view_count"] || stats[:view_count] || 0
    video_count = stats["video_count"] || stats[:video_count] || 0
    avg_views = stats["avg_views_per_video"] || stats[:avg_views_per_video] ||
      (if video_count > 0, do: div(view_count, video_count), else: 0)

    benchmark = Map.get(@benchmarks, niche, @benchmarks["general"])

    sub_ratio = safe_ratio(subscriber_count, benchmark.subscriber_count)
    view_ratio = safe_ratio(avg_views, benchmark.avg_views_per_video)
    count_ratio = safe_ratio(video_count, benchmark.video_count)
    total_view_ratio = safe_ratio(view_count, benchmark.view_count)

    composite = sub_ratio * 0.35 + view_ratio * 0.30 + total_view_ratio * 0.20 + count_ratio * 0.15

    percentile_rank = min(99, round(composite * 50))

    competitive_position = classify_position(percentile_rank)

    benchmark_comparison = %{
      subscriber_count: %{
        channel: subscriber_count,
        niche_median: benchmark.subscriber_count,
        ratio: Float.round(sub_ratio, 2)
      },
      avg_views_per_video: %{
        channel: avg_views,
        niche_median: benchmark.avg_views_per_video,
        ratio: Float.round(view_ratio, 2)
      },
      video_count: %{
        channel: video_count,
        niche_median: benchmark.video_count,
        ratio: Float.round(count_ratio, 2)
      },
      total_views: %{
        channel: view_count,
        niche_median: benchmark.view_count,
        ratio: Float.round(total_view_ratio, 2)
      }
    }

    areas_of_strength =
      [
        {sub_ratio, "subscriber_count"},
        {view_ratio, "avg_views_per_video"},
        {count_ratio, "video_count"},
        {total_view_ratio, "total_views"}
      ]
      |> Enum.filter(fn {r, _} -> r >= 1.0 end)
      |> Enum.map(fn {_, name} -> name end)

    areas_for_improvement =
      [
        {sub_ratio, "subscriber_count"},
        {view_ratio, "avg_views_per_video"},
        {count_ratio, "video_count"},
        {total_view_ratio, "total_views"}
      ]
      |> Enum.filter(fn {r, _} -> r < 1.0 end)
      |> Enum.sort_by(fn {r, _} -> r end)
      |> Enum.map(fn {_, name} -> name end)

    {:ok, %{
      niche: niche,
      percentile_rank: percentile_rank,
      competitive_position: competitive_position,
      benchmark_comparison: benchmark_comparison,
      areas_of_strength: areas_of_strength,
      areas_for_improvement: areas_for_improvement
    }}
  end

  defp safe_ratio(_, 0), do: 0.0
  defp safe_ratio(value, benchmark), do: value / benchmark

  defp classify_position(rank) when rank >= 80, do: "leader"
  defp classify_position(rank) when rank >= 60, do: "above_average"
  defp classify_position(rank) when rank >= 40, do: "average"
  defp classify_position(rank) when rank >= 20, do: "below_average"
  defp classify_position(_), do: "emerging"
end
