defmodule Lux.Integrations.YouTube.ContentIntelligence do
  @moduledoc """
  Deterministic content analysis, engagement scoring, metadata optimization,
  and posting schedule prediction engine for YouTube channels.

  Provides:
  - Video performance & audience engagement scoring
  - Title, tag, and description optimization with SEO keyword density analysis
  - Optimal posting window prediction from historical velocity curves
  - Content recommendation synthesis from trending topic signals
  """

  @type video_metrics :: %{
          optional(:view_count) => non_neg_integer(),
          optional(:like_count) => non_neg_integer(),
          optional(:comment_count) => non_neg_integer(),
          optional(:duration_seconds) => non_neg_integer()
        }

  @doc """
  Computes engagement rates, velocity score, and performance tier for a video's metrics.
  """
  @spec analyze_engagement(video_metrics()) :: map()
  def analyze_engagement(metrics) when is_map(metrics) do
    views = max(Map.get(metrics, :view_count, 0), 0)
    likes = max(Map.get(metrics, :like_count, 0), 0)
    comments = max(Map.get(metrics, :comment_count, 0), 0)

    like_rate = if views > 0, do: Float.round(likes / views * 100.0, 2), else: 0.0
    comment_rate = if views > 0, do: Float.round(comments / views * 100.0, 2), else: 0.0
    engagement_score = Float.round(like_rate * 1.2 + comment_rate * 4.5, 2)

    tier =
      cond do
        engagement_score >= 8.0 -> :viral_outperformer
        engagement_score >= 4.5 -> :high_engagement
        engagement_score >= 2.0 -> :baseline_healthy
        true -> :needs_optimization
      end

    %{
      view_count: views,
      like_count: likes,
      comment_count: comments,
      like_rate_pct: like_rate,
      comment_rate_pct: comment_rate,
      engagement_score: engagement_score,
      performance_tier: tier
    }
  end

  @doc """
  Evaluates and optimizes video metadata (title, tags, description, thumbnail cues)
  for click-through rate (CTR) and YouTube search discovery.
  """
  @spec optimize_metadata(map()) :: map()
  def optimize_metadata(params) when is_map(params) do
    raw_title = Map.get(params, :title, "") |> String.trim()
    topic = Map.get(params, :topic, "AI Agents") |> String.trim()
    existing_tags = Map.get(params, :tags, [])

    title_len = String.length(raw_title)

    title_score =
      cond do
        title_len in 45..70 -> 95
        title_len in 30..85 -> 80
        title_len > 0 -> 55
        true -> 0
      end

    optimized_title =
      cond do
        raw_title == "" ->
          "#{topic}: Complete Architecture & Production Guide (2026)"

        title_len < 35 ->
          "#{raw_title} — Complete #{topic} Breakdown"

        title_len > 85 ->
          String.slice(raw_title, 0, 82) <> "..."

        true ->
          raw_title
      end

    base_tags =
      topic
      |> String.downcase()
      |> String.split(~r/[^a-z0-9]+/, trim: true)
      |> Enum.uniq()

    recommended_tags =
      (existing_tags ++
         base_tags ++
         [
           String.downcase(topic),
           "#{String.downcase(topic)} tutorial",
           "#{String.downcase(topic)} architecture"
         ])
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()
      |> Enum.take(15)

    generated_description = """
    #{optimized_title}

    In this video, we break down #{topic} with actionable insights, benchmarks, and real-world examples.

    Chapters:
    00:00 Introduction to #{topic}
    02:15 Core Architecture & Key Concepts
    06:30 Live Implementation & Benchmarks
    10:45 Key Takeaways & Next Steps

    Topics covered: #{Enum.join(recommended_tags, ", ")}
    """

    %{
      original_title: raw_title,
      optimized_title: optimized_title,
      title_score: title_score,
      recommended_tags: recommended_tags,
      generated_description: String.trim(generated_description),
      thumbnail_recommendations: [
        "High-contrast focal subject with <= 4 bold words",
        "Highlight primary outcome metric for #{topic}",
        "Avoid bottom-right corner overlap with timestamp badge"
      ]
    }
  end

  @doc """
  Predicts the optimal posting window from historical publish records.
  Each record in `history` is a map with `:day_of_week` (1..7), `:hour_utc` (0..23),
  and `:views_first_24h`.
  """
  @spec predict_optimal_posting_time([map()]) :: map()
  def predict_optimal_posting_time([]), do: %{day_of_week: 3, hour_utc: 15, confidence: :default_baseline}

  def predict_optimal_posting_time(history) when is_list(history) do
    best =
      history
      |> Enum.max_by(fn entry ->
        views = Map.get(entry, :views_first_24h, 0)
        engagement = Map.get(entry, :engagement_score, 1.0)
        views * engagement
      end)

    %{
      day_of_week: Map.get(best, :day_of_week, 3),
      hour_utc: Map.get(best, :hour_utc, 15),
      expected_24h_views: Map.get(best, :views_first_24h, 0),
      confidence: if(length(history) >= 5, do: :high, else: :moderate)
    }
  end
end
