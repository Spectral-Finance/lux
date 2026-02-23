defmodule Lux.Prisms.YouTube.AnalyzeVideoPerformance do
  @moduledoc """
  A prism for analyzing YouTube video performance and generating actionable recommendations.

  Fetches video analytics via GetVideoAnalytics lens, computes a performance tier
  (viral/above_average/average/below_average) based on view count and engagement rate,
  and produces a prioritized list of content improvement recommendations.

  ## Examples

      iex> AnalyzeVideoPerformance.handler(%{
      ...>   "video_id" => "dQw4w9WgXcQ",
      ...>   "channel_avg_views" => 50_000
      ...> }, %{})
      {:ok, %{
        video_id: "dQw4w9WgXcQ",
        performance_tier: "viral",
        content_score: 95,
        recommendations: ["Capitalize on momentum with a follow-up video"],
        metrics: %{view_count: 1_300_000_000, engagement_rate: 1.15}
      }}
  """

  use Lux.Prism,
    name: "Analyze Video Performance",
    description: "Fetches video analytics, computes performance tier and content score, and generates actionable recommendations",
    input_schema: %{
      type: :object,
      properties: %{
        video_id: %{
          type: :string,
          description: "The YouTube video ID to analyze"
        },
        channel_avg_views: %{
          type: :integer,
          description: "Average views per video for the channel, used for relative benchmarking",
          default: 10_000
        }
      },
      required: ["video_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        video_id: %{type: :string},
        performance_tier: %{type: :string, enum: ["viral", "above_average", "average", "below_average"]},
        content_score: %{type: :integer, minimum: 0, maximum: 100},
        recommendations: %{type: :array, items: %{type: :string}},
        metrics: %{type: :object}
      }
    }

  alias Lux.Lenses.YouTube.Analytics.GetVideoAnalytics

  @doc """
  Analyzes video performance by fetching analytics and computing actionable insights.
  """
  def handler(params, _agent) do
    video_id = params["video_id"] || params[:video_id]
    channel_avg_views = params["channel_avg_views"] || params[:channel_avg_views] || 10_000

    with {:ok, analytics} <- GetVideoAnalytics.focus(%{"video_id" => video_id}, %{}) do
      tier = classify_performance_tier(analytics, channel_avg_views)
      score = compute_content_score(analytics, tier)
      recs = generate_recommendations(analytics, tier)

      {:ok, %{
        video_id: video_id,
        title: analytics.title,
        performance_tier: tier,
        content_score: score,
        recommendations: recs,
        metrics: %{
          view_count: analytics.view_count,
          like_count: analytics.like_count,
          comment_count: analytics.comment_count,
          engagement_rate: analytics.engagement_rate,
          estimated_revenue: analytics.estimated_revenue_potential
        }
      }}
    end
  end

  defp classify_performance_tier(analytics, channel_avg) do
    view_ratio = if channel_avg > 0, do: analytics.view_count / channel_avg, else: 1.0

    cond do
      view_ratio >= 5.0 and analytics.engagement_rate >= 5.0 -> "viral"
      view_ratio >= 2.0 or analytics.engagement_rate >= 3.0  -> "above_average"
      view_ratio >= 0.5                                       -> "average"
      true                                                    -> "below_average"
    end
  end

  defp compute_content_score(analytics, tier) do
    tier_base = case tier do
      "viral"         -> 70
      "above_average" -> 55
      "average"       -> 40
      "below_average" -> 20
    end

    engagement_bonus = min(round(analytics.engagement_rate * 3), 20)
    tag_bonus = if length(analytics.tags) >= 5, do: 5, else: 0
    desc_bonus = if is_binary(analytics.description) and String.length(analytics.description) > 100, do: 5, else: 0

    min(tier_base + engagement_bonus + tag_bonus + desc_bonus, 100)
  end

  defp generate_recommendations(analytics, tier) do
    base = case tier do
      "viral" ->
        ["Capitalize on momentum with a follow-up video on the same topic",
         "Pin this video and feature it in your channel trailer",
         "Create a community post highlighting key moments"]

      "above_average" ->
        ["Promote this video in your next upload's end screen",
         "Analyze what resonated and replicate the format",
         "Consider a Part 2 to sustain audience interest"]

      "average" ->
        ["Refresh the title with stronger keywords",
         "Add cards and end screens to improve session time",
         "Share on social media to boost discovery"]

      "below_average" ->
        ["Revise the title and thumbnail for better click-through rate",
         "Add relevant tags and improve the description SEO",
         "Promote in relevant communities and playlists"]
    end

    engagement_recs =
      if analytics.engagement_rate < 1.0 do
        ["Add a call-to-action in the first 30 seconds to boost engagement"]
      else
        []
      end

    tag_recs =
      if length(analytics.tags) < 5 do
        ["Expand tags to at least 10 relevant keywords for better discoverability"]
      else
        []
      end

    desc_recs =
      if is_binary(analytics.description) and String.length(analytics.description) < 100 do
        ["Expand video description with timestamps, links, and relevant keywords"]
      else
        []
      end

    base ++ engagement_recs ++ tag_recs ++ desc_recs
  end
end
