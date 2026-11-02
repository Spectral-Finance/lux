defmodule Lux.YouTube.ContentIntelligence do
  @moduledoc """
  Unified coordinator for YouTube Content Intelligence in Lux.

  Provides high-level APIs for:
  - Video performance analytics & view velocity (`evaluate_performance/2`, `analyze_retention/1`)
  - Audience loyalty & traffic source health (`analyze_audience/1`)
  - Content gap discovery & topic recommendations (`recommend_topics/2`, `identify_gaps/2`)
  - Optimal upload timing window prediction (`predict_posting_time/1`)
  - Title and thumbnail CTR optimization (`analyze_title/1`, `generate_title_variants/1`, `audit_thumbnail/1`)
  - Automated SEO metadata package generation (`generate_metadata/1`)
  - Trending topic momentum analysis (`analyze_trends/1`)
  - Comprehensive end-to-end video intelligence audit (`audit_video/2`)
  """

  alias Lux.YouTube.ContentIntelligence.{
    AudienceEngagement,
    MetadataGenerator,
    PerformanceAnalytics,
    PostingTimePredictor,
    RecommendationEngine,
    TitleThumbnailOptimizer,
    TrendingTopicAnalyzer
  }

  defdelegate evaluate_performance(stats, baseline \\ %{}), to: PerformanceAnalytics
  defdelegate analyze_retention(curve), to: PerformanceAnalytics, as: :analyze_retention_curve

  defdelegate analyze_audience(data), to: AudienceEngagement

  defdelegate recommend_topics(past_videos, niche \\ "tech"), to: RecommendationEngine, as: :recommend_next_topics
  defdelegate identify_gaps(queries, titles), to: RecommendationEngine, as: :identify_content_gaps

  defdelegate predict_posting_time(opts \\ %{}), to: PostingTimePredictor, as: :predict_optimal_time
  defdelegate score_scheduled_slot(dt), to: PostingTimePredictor

  defdelegate analyze_title(title), to: TitleThumbnailOptimizer
  defdelegate generate_title_variants(topic), to: TitleThumbnailOptimizer, as: :generate_variants
  defdelegate audit_thumbnail(params), to: TitleThumbnailOptimizer

  defdelegate generate_metadata(params), to: MetadataGenerator, as: :generate_package

  defdelegate analyze_trends(niche), to: TrendingTopicAnalyzer, as: :analyze_niche_trends
  defdelegate evaluate_custom_topic(topic, niche, metrics \\ %{}), to: TrendingTopicAnalyzer

  @doc """
  Performs an end-to-end holistic audit of a video's telemetry, title strength, and audience engagement.
  """
  @spec audit_video(map(), map()) :: map()
  def audit_video(video_data, channel_baseline \\ %{}) do
    title = Map.get(video_data, :title, Map.get(video_data, "title", "Untitled Video"))
    stats = Map.get(video_data, :stats, Map.get(video_data, "stats", video_data))
    audience_data = Map.get(video_data, :audience, Map.get(video_data, "audience", video_data))
    thumbnail_data = Map.get(video_data, :thumbnail, Map.get(video_data, "thumbnail", %{}))
    retention_curve = Map.get(stats, :retention_curve, Map.get(stats, "retention_curve", []))

    perf = evaluate_performance(stats, channel_baseline)
    retention = analyze_retention(retention_curve)
    audience = analyze_audience(audience_data)
    title_eval = analyze_title(title)
    thumbnail_eval = audit_thumbnail(thumbnail_data)

    overall_health_score =
      Float.round(
        perf.velocity_score * 0.35 +
          audience.loyalty_score * 0.30 +
          title_eval.ctr_potential_score * 0.20 +
          thumbnail_eval.mobile_readability_score * 0.15,
        1
      )

    verdict =
      cond do
        overall_health_score >= 80.0 -> :high_performer
        overall_health_score >= 60.0 -> :stable_grower
        true -> :needs_optimization
      end

    %{
      title: title,
      overall_health_score: overall_health_score,
      verdict: verdict,
      performance: perf,
      retention_analysis: retention,
      audience_profile: audience,
      title_evaluation: title_eval,
      thumbnail_evaluation: thumbnail_eval,
      actionable_recommendations: compile_recommendations(perf, audience, title_eval, thumbnail_eval)
    }
  end

  defp compile_recommendations(perf, audience, title_eval, thumbnail_eval) do
    recs = []

    recs =
      if title_eval.mobile_truncation_risk do
        ["Shorten title under 65 characters to eliminate mobile viewport truncation." | recs]
      else
        recs
      end

    recs =
      if perf.hook_retention_rate < 60.0 do
        ["First 30 seconds lost >40% of viewers; tighten video intro and deliver on hook immediately." | recs]
      else
        recs
      end

    recs =
      if thumbnail_eval.visual_clutter_verdict == :cluttered do
        ["Reduce thumbnail text overlay to 3-4 high-contrast words for better mobile visibility." | recs]
      else
        recs
      end

    recs =
      if audience.engagement_grade in [:c, :f] do
        ["Insert an explicit question or pinned comment to boost comment density and algorithmic push." | recs]
      else
        recs
      end

    Enum.reverse(recs)
  end
end
