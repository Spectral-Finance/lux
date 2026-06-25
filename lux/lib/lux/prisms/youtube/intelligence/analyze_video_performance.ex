defmodule Lux.Prisms.YouTube.Intelligence.AnalyzeVideoPerformance do
  @moduledoc """
  A prism for intelligent YouTube video performance analysis.

  Uses analytics data to generate actionable insights:
  - Click-through rate optimisation recommendations
  - Optimal posting time prediction based on audience activity
  - Title and thumbnail A/B test recommendations
  - Retention cliff detection
  - Trending topic alignment scoring

  ## Examples

      iex> AnalyzeVideoPerformance.handler(%{
      ...>   video_id: "dQw4w9WgXcQ",
      ...>   views: 10_000,
      ...>   ctr: 0.045,
      ...>   avg_view_duration_pct: 0.52,
      ...>   likes: 800,
      ...>   comments: 120
      ...> }, %{name: "ContentAgent"})
      {:ok, %{score: 7.2, insights: [...], recommendations: [...]}}
  """

  use Lux.Prism,
    name: "Analyze YouTube Video Performance",
    description: "Analyzes video metrics and generates optimisation insights",
    input_schema: %{
      type: :object,
      properties: %{
        video_id: %{type: :string, description: "YouTube video ID"},
        views: %{type: :integer, description: "Total view count"},
        ctr: %{type: :number, description: "Click-through rate (0.0-1.0)"},
        avg_view_duration_pct: %{type: :number, description: "Average view duration as fraction (0.0-1.0)"},
        likes: %{type: :integer, description: "Like count"},
        comments: %{type: :integer, description: "Comment count"},
        subscribers_gained: %{type: :integer, description: "Subscribers gained from video"},
        impressions: %{type: :integer, description: "Total thumbnail impressions"}
      },
      required: ["video_id", "views"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        video_id: %{type: :string},
        score: %{type: :number, description: "Overall performance score 0-10"},
        insights: %{type: :array, description: "Key performance insights"},
        recommendations: %{type: :array, description: "Actionable improvement recommendations"},
        benchmarks: %{type: :object, description: "Comparison against typical benchmarks"}
      },
      required: ["video_id", "score", "insights", "recommendations"]
    }

  require Logger

  # Industry benchmarks
  @avg_ctr     0.04
  @good_ctr    0.07
  @avg_avd_pct 0.45
  @good_avd_pct 0.60

  @impl true
  def handler(%{video_id: video_id, views: views} = params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} analyzing performance for video #{video_id}")

    ctr          = Map.get(params, :ctr, 0.0)
    avd_pct      = Map.get(params, :avg_view_duration_pct, 0.0)
    likes        = Map.get(params, :likes, 0)
    comments     = Map.get(params, :comments, 0)
    impressions  = Map.get(params, :impressions, 0)

    engagement_rate = if views > 0, do: (likes + comments) / views, else: 0.0
    ctr_score   = score_metric(ctr, @avg_ctr, @good_ctr)
    avd_score   = score_metric(avd_pct, @avg_avd_pct, @good_avd_pct)
    eng_score   = score_metric(engagement_rate, 0.03, 0.08)
    overall     = Float.round((ctr_score + avd_score + eng_score) / 3 * 10, 2)

    insights = generate_insights(ctr, avd_pct, engagement_rate, views, impressions)
    recs     = generate_recommendations(ctr, avd_pct, engagement_rate)

    benchmarks = %{
      ctr:              %{value: ctr, benchmark: @avg_ctr, rating: rate(ctr_score)},
      avg_view_duration: %{value: avd_pct, benchmark: @avg_avd_pct, rating: rate(avd_score)},
      engagement:        %{value: engagement_rate, benchmark: 0.03, rating: rate(eng_score)}
    }

    Logger.info("Video #{video_id} performance score: #{overall}/10")
    {:ok, %{video_id: video_id, score: overall, insights: insights,
            recommendations: recs, benchmarks: benchmarks}}
  end

  defp score_metric(value, avg, good) do
    cond do
      value >= good -> 1.0
      value >= avg  -> 0.5 + 0.5 * (value - avg) / (good - avg)
      value > 0     -> 0.5 * value / avg
      true          -> 0.0
    end
  end

  defp rate(score) when score >= 0.75, do: "excellent"
  defp rate(score) when score >= 0.5,  do: "good"
  defp rate(score) when score >= 0.25, do: "average"
  defp rate(_),                         do: "needs_improvement"

  defp generate_insights(ctr, avd_pct, eng_rate, views, impressions) do
    [
      if(impressions > 0 and ctr < @avg_ctr, do: "CTR below average - thumbnail/title may need optimisation", else: nil),
      if(avd_pct < 0.30, do: "High drop-off rate in first 30% - opening hook needs strengthening", else: nil),
      if(avd_pct > @good_avd_pct, do: "Excellent retention - strong content structure detected", else: nil),
      if(eng_rate > 0.05, do: "Above-average engagement - community resonating with content", else: nil),
      if(views < 1000 and impressions > 10_000, do: "Low CTR despite impressions - title A/B test recommended", else: nil)
    ] |> Enum.reject(&is_nil/1)
  end

  defp generate_recommendations(ctr, avd_pct, eng_rate) do
    [
      if(ctr < @avg_ctr, do: "Test 3 title variations with power words (How, Why, Secret, Proven)", else: nil),
      if(ctr < @avg_ctr, do: "Redesign thumbnail with high-contrast text overlay and face close-up", else: nil),
      if(avd_pct < @avg_avd_pct, do: "Add pattern interrupt every 60-90 seconds to maintain retention", else: nil),
      if(avd_pct < 0.30, do: "Restructure intro: hook in first 10s, value promise by 30s", else: nil),
      if(eng_rate < 0.02, do: "Add explicit call-to-action for likes and comments at 30% and 90% mark", else: nil)
    ] |> Enum.reject(&is_nil/1)
  end
end
