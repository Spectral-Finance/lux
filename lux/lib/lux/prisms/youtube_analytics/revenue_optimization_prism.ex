defmodule Lux.Prisms.YoutubeAnalytics.RevenueOptimizationPrism do
  @moduledoc """
  Prism for analyzing and optimizing YouTube revenue per view and CPM trends.

  Provides revenue optimization recommendations based on content type,
  audience demographics, and historical CPM data.
  """

  use Lux.Prism,
    name: "YouTube Revenue Optimization",
    description: "Analyzes and optimizes YouTube revenue per view, CPM trends, and monetization strategies",
    input_schema: %{
      type: :object,
      properties: %{
        revenue_data: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              date: %{type: :string},
              estimated_revenue: %{type: :float},
              views: %{type: :integer},
              cpm: %{type: :float}
            }
          },
          description: "Historical revenue data"
        },
        video_categories: %{
          type: :array,
          items: %{type: :string},
          description: "Video categories to analyze"
        },
        currency: %{
          type: :string,
          description: "Currency code",
          default: "USD"
        }
      },
      required: ["revenue_data"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        revenue_analysis: %{
          type: :object,
          properties: %{
            total_revenue: %{type: :float},
            avg_cpm: %{type: :float},
            revenue_per_view: %{type: :float},
            revenue_trend: %{type: :string}
          }
        },
        recommendations: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              category: %{type: :string},
              recommendation: %{type: :string},
              priority: %{type: :string},
              estimated_impact: %{type: :string}
            }
          }
        },
        optimization_score: %{type: :float}
      }
    }

  @doc """
  Optimize revenue strategy based on historical data.
  """
  def transform(params) when is_map(params) do
    revenue_data = Map.get(params, :revenue_data, [])
    video_categories = Map.get(params, :video_categories, [])

    if length(revenue_data) == 0 do
      {:error, "No revenue data provided"}
    else
      analysis = analyze_revenue(revenue_data)
      recommendations = generate_recommendations(revenue_data, video_categories)
      optimization_score = calculate_optimization_score(revenue_data, recommendations)

      {:ok, %{
        revenue_analysis: analysis,
        recommendations: recommendations,
        optimization_score: Float.round(optimization_score, 2)
      }}
    end
  end

  defp analyze_revenue(data) do
    total_revenue = Enum.sum(Enum.map(data, &(&1.estimated_revenue || 0)))
    total_views = Enum.sum(Enum.map(data, &(&1.views || 0)))
    avg_cpm = if length(data) > 0 do
      Enum.sum(Enum.map(data, &(&1.cpm || 0))) / length(data)
    else
      0.0
    end

    revenue_per_view = if total_views > 0, do: total_revenue / total_views, else: 0.0

    %{
      total_revenue: Float.round(total_revenue, 2),
      total_views: total_views,
      avg_cpm: Float.round(avg_cpm, 2),
      revenue_per_view: Float.round(revenue_per_view, 4),
      revenue_trend: determine_revenue_trend(data)
    }
  end

  defp generate_recommendations(revenue_data, video_categories) do
    avg_cpm = if length(revenue_data) > 0 do
      Enum.sum(Enum.map(revenue_data, &(&1.cpm || 0))) / length(revenue_data)
    else
      0
    end

    rec1 = if avg_cpm < 3.0 do
      %{category: "CPM Optimization", recommendation: "Create content in higher-CPM niches (finance, tech, business)", priority: "high", estimated_impact: "20-50% CPM increase"}
    end

    rec2 = %{category: "Content Strategy", recommendation: "Increase upload frequency to capitalize on algorithm favorability", priority: "medium", estimated_impact: "15-30% view increase"}
    rec3 = %{category: "Retention", recommendation: "Optimize first 30 seconds to improve average view duration and ad impressions", priority: "high", estimated_impact: "10-25% revenue increase"}

    rec4 = if length(video_categories) > 0 do
      %{category: "Diversification", recommendation: "Diversify content across #{length(video_categories)} categories to reduce revenue volatility", priority: "medium", estimated_impact: "Reduced revenue variance"}
    end

    [rec1, rec2, rec3, rec4] |> Enum.reject(&is_nil/1)
  end

  defp calculate_optimization_score(_data, recommendations) do
    base_score = 100
    high_count = Enum.count(recommendations, &(&1.priority == "high"))
    med_count = Enum.count(recommendations, &(&1.priority == "medium"))
    max(0, min(100, base_score - (high_count * 15) - (med_count * 8)))
  end

  defp determine_revenue_trend(data) do
    sorted = Enum.sort_by(data, &(&1.date))
    half = max(div(length(sorted), 2), 1)
    {first_half, second_half} = Enum.split(sorted, half)

    avg_first = avg_revenue(first_half)
    avg_second = avg_revenue(second_half)

    cond do
      avg_second > avg_first * 1.1 -> "growing"
      avg_second < avg_first * 0.9 -> "declining"
      true -> "stable"
    end
  end

  defp avg_revenue(data) do
    if length(data) == 0, do: 0.0,
    else: Enum.sum(Enum.map(data, &(&1.estimated_revenue || 0))) / length(data)
  end
end
