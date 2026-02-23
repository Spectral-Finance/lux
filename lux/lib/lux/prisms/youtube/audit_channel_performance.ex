defmodule Lux.Prisms.YouTube.AuditChannelPerformance do
  @moduledoc """
  A prism for performing a comprehensive YouTube channel performance audit.

  Computes an audit score (0-100), identifies strengths and weaknesses,
  and generates actionable improvement recommendations based on the
  supplied channel statistics and recent video performance data.

  This prism performs local computation only — no external API calls.

  ## Examples

      iex> AuditChannelPerformance.handler(%{
      ...>   "subscriber_count" => 50_000,
      ...>   "view_count" => 3_000_000,
      ...>   "video_count" => 180,
      ...>   "recent_videos" => [
      ...>     %{"view_count" => 8_500, "like_count" => 400, "comment_count" => 35},
      ...>     %{"view_count" => 12_000, "like_count" => 600, "comment_count" => 50}
      ...>   ]
      ...> }, %{})
      {:ok, %{
        audit_score: 72,
        strengths: ["upload_consistency", "engagement"],
        weaknesses: ["growth_rate"],
        action_items: ["Increase upload frequency to at least 1 video per week", ...]
      }}
  """

  use Lux.Prism,
    name: "Audit YouTube Channel Performance",
    description: "Analyses channel stats and produces an audit score, strengths, weaknesses, and action items",
    input_schema: %{
      type: :object,
      properties: %{
        subscriber_count: %{
          type: :integer,
          description: "Total channel subscriber count"
        },
        view_count: %{
          type: :integer,
          description: "All-time channel view count"
        },
        video_count: %{
          type: :integer,
          description: "Total number of published videos"
        },
        recent_videos: %{
          type: :array,
          description: "List of recent video stat maps (view_count, like_count, comment_count)",
          items: %{
            type: :object,
            properties: %{
              view_count: %{type: :integer},
              like_count: %{type: :integer},
              comment_count: %{type: :integer}
            }
          }
        }
      },
      required: ["subscriber_count", "view_count", "video_count"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        audit_score: %{
          type: :integer,
          description: "Overall channel health score from 0 to 100"
        },
        strengths: %{
          type: :array,
          description: "List of identified strength areas",
          items: %{type: :string}
        },
        weaknesses: %{
          type: :array,
          description: "List of identified weakness areas",
          items: %{type: :string}
        },
        action_items: %{
          type: :array,
          description: "Prioritised list of recommended actions",
          items: %{type: :string}
        }
      },
      required: ["audit_score", "strengths", "weaknesses", "action_items"]
    }

  require Logger

  def handler(params, agent) do
    agent_name = get_in(agent, [:agent, :name]) || agent[:name] || "Unknown"
    Logger.info("Agent #{agent_name} auditing channel performance")

    subscriber_count = params["subscriber_count"] || params[:subscriber_count] || 0
    view_count = params["view_count"] || params[:view_count] || 0
    video_count = params["video_count"] || params[:video_count] || 0
    recent_videos = params["recent_videos"] || params[:recent_videos] || []

    upload_score = score_upload_consistency(video_count)
    engagement_score = score_engagement(recent_videos, subscriber_count)
    growth_score = score_growth(subscriber_count, view_count)
    content_score = score_content_quality(recent_videos)

    audit_score = min(100, upload_score + engagement_score + growth_score + content_score)

    {strengths, upload_actions} = evaluate_upload(upload_score)
    {eng_strengths, eng_weaknesses, eng_actions} = evaluate_engagement(engagement_score, recent_videos, subscriber_count)
    {growth_strengths, growth_weaknesses, growth_actions} = evaluate_growth(growth_score, subscriber_count)
    {content_strengths, content_weaknesses, content_actions} = evaluate_content(content_score, recent_videos)

    all_strengths = strengths ++ eng_strengths ++ growth_strengths ++ content_strengths
    all_weaknesses = eng_weaknesses ++ growth_weaknesses ++ content_weaknesses
    all_actions = upload_actions ++ eng_actions ++ growth_actions ++ content_actions

    {:ok, %{
      audit_score: audit_score,
      strengths: Enum.uniq(all_strengths),
      weaknesses: Enum.uniq(all_weaknesses),
      action_items: Enum.take(all_actions, 8)
    }}
  end

  defp score_upload_consistency(video_count) do
    cond do
      video_count >= 200 -> 25
      video_count >= 100 -> 20
      video_count >= 50 -> 15
      video_count >= 20 -> 10
      video_count >= 5 -> 5
      true -> 0
    end
  end

  defp evaluate_upload(score) when score >= 20 do
    {["upload_consistency"], []}
  end
  defp evaluate_upload(_) do
    {[], ["Increase upload frequency to at least 1 video per week",
          "Build a content calendar to maintain a consistent schedule"]}
  end

  defp score_engagement([], _), do: 5
  defp score_engagement(recent_videos, subscriber_count) when subscriber_count > 0 do
    avg_engagement = avg_engagement_rate(recent_videos, subscriber_count)
    cond do
      avg_engagement >= 5.0 -> 25
      avg_engagement >= 3.0 -> 20
      avg_engagement >= 1.5 -> 15
      avg_engagement >= 0.5 -> 8
      true -> 3
    end
  end
  defp score_engagement(_, _), do: 5

  defp evaluate_engagement(score, recent_videos, subscriber_count) do
    rate = avg_engagement_rate(recent_videos, subscriber_count)
    cond do
      score >= 20 ->
        {["engagement"], [], []}
      score >= 10 ->
        {[], [], ["Add strong call-to-actions in your videos to boost likes and comments",
                  "Respond to every comment in the first 24 hours to increase engagement signals"]}
      true ->
        {[], ["engagement"],
         ["Focus on creating discussion-worthy content with open-ended questions",
          "Aim for an engagement rate above 3% (current: #{Float.round(rate, 2)}%)",
          "Use community posts to maintain audience interaction between videos"]}
    end
  end

  defp score_growth(0, _), do: 0
  defp score_growth(subscriber_count, view_count) when view_count > 0 do
    ratio = subscriber_count / view_count * 100
    cond do
      subscriber_count >= 1_000_000 -> 25
      subscriber_count >= 100_000 -> 22
      subscriber_count >= 10_000 && ratio >= 1.0 -> 18
      subscriber_count >= 1_000 -> 12
      subscriber_count >= 100 -> 6
      true -> 2
    end
  end
  defp score_growth(_, _), do: 2

  defp evaluate_growth(score, subscriber_count) do
    cond do
      score >= 20 ->
        {["growth"], [], []}
      score >= 12 ->
        {[], [], ["Optimise video titles and thumbnails for higher click-through rates",
                  "Research trending keywords in your niche using YouTube Search Insights"]}
      true ->
        {[], ["growth_rate"],
         ["Collaborate with channels of similar size to cross-promote content",
          "Run a structured subscriber drive campaign (e.g., giveaway or challenge)",
          "Current subscribers: #{format_number(subscriber_count)} — target milestone: #{next_milestone(subscriber_count)}"]}
    end
  end

  defp score_content_quality([]), do: 5
  defp score_content_quality(recent_videos) do
    avg_v = avg_views(recent_videos)
    cond do
      avg_v >= 100_000 -> 25
      avg_v >= 10_000 -> 20
      avg_v >= 1_000 -> 15
      avg_v >= 100 -> 8
      true -> 3
    end
  end

  defp evaluate_content(score, recent_videos) do
    avg_v = avg_views(recent_videos)
    cond do
      score >= 20 ->
        {["content_quality"], [], []}
      score >= 10 ->
        {[], [], ["A/B test different thumbnail styles to improve click-through rates",
                  "Study your top-performing videos and replicate the format"]}
      true ->
        {[], ["content_quality"],
         ["Invest in better audio/video production quality",
          "Average recent views: #{format_number(round(avg_v))} — aim for 10x improvement",
          "Analyse competitor content to identify gaps and opportunities in your niche"]}
    end
  end

  defp avg_engagement_rate([], _), do: 0.0
  defp avg_engagement_rate(videos, subscriber_count) when subscriber_count > 0 do
    total_rate = Enum.reduce(videos, 0.0, fn v, acc ->
      views = v["view_count"] || v[:view_count] || 0
      likes = v["like_count"] || v[:like_count] || 0
      comments = v["comment_count"] || v[:comment_count] || 0
      rate = if views > 0, do: (likes + comments) / views * 100, else: 0.0
      acc + rate
    end)
    total_rate / length(videos)
  end
  defp avg_engagement_rate(_, _), do: 0.0

  defp avg_views([]), do: 0.0
  defp avg_views(videos) do
    total = Enum.reduce(videos, 0, fn v, acc ->
      acc + (v["view_count"] || v[:view_count] || 0)
    end)
    total / length(videos)
  end

  defp format_number(n) when n >= 1_000_000, do: "#{Float.round(n / 1_000_000, 1)}M"
  defp format_number(n) when n >= 1_000, do: "#{Float.round(n / 1_000, 1)}K"
  defp format_number(n), do: "#{n}"

  defp next_milestone(n) when n < 1_000, do: "1K"
  defp next_milestone(n) when n < 10_000, do: "10K"
  defp next_milestone(n) when n < 100_000, do: "100K"
  defp next_milestone(n) when n < 1_000_000, do: "1M"
  defp next_milestone(_), do: "10M"
end
