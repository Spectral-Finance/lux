defmodule Lux.YouTube.ContentIntelligence do
  @moduledoc """
  Unified facade for the YouTube Content Intelligence System.

  Provides a single entry point to all YouTube content analysis,
  optimization, and automated decision-making capabilities.

  ## Core Features

    - Video performance analytics
    - Audience engagement analysis
    - Content recommendation engine
    - Optimal posting time prediction
    - Title and thumbnail optimization
    - Tag optimization and description generation
    - Trending topic analysis
  """

  alias Lux.YouTube.ContentIntelligence.PerformanceAnalytics
  alias Lux.YouTube.ContentIntelligence.AudienceEngagement
  alias Lux.YouTube.ContentIntelligence.RecommendationEngine
  alias Lux.YouTube.ContentIntelligence.PostingTimePredictor
  alias Lux.YouTube.ContentIntelligence.TitleThumbnailOptimizer
  alias Lux.YouTube.ContentIntelligence.MetadataGenerator
  alias Lux.YouTube.ContentIntelligence.TrendingTopicAnalyzer

  @doc """
  Runs a holistic analysis of a video across all intelligence modules.
  """
  def analyze_video(video_data, options \\ [])

  def analyze_video(video_data, _options) when is_map(video_data) do
    results = %{
      performance: safe_analyze(&PerformanceAnalytics.analyze/1, video_data),
      engagement: safe_analyze(&AudienceEngagement.analyze/1, video_data)
    }

    results = add_optional_result(results, video_data, :historical_videos,
      &RecommendationEngine.recommend/1, :recommendations,
      fn vd -> %{historical_videos: vd.historical_videos, channel_niche: Map.get(vd, :channel_niche, "general")} end)

    results = add_optional_result(results, video_data, :historical_performance,
      &PostingTimePredictor.predict/1, :posting_times,
      fn vd -> %{historical_performance: vd.historical_performance, timezone: Map.get(vd, :timezone, "UTC")} end)

    results = add_optional_result(results, video_data, :title,
      &TitleThumbnailOptimizer.optimize_title/1, :title_optimization,
      fn vd -> %{title: vd.title, target_audience: Map.get(vd, :target_audience, "general")} end)

    results = add_optional_result(results, video_data, :video_topic,
      &MetadataGenerator.generate/1, :metadata,
      fn vd -> %{video_topic: vd.video_topic, video_description: Map.get(vd, :video_description, ""),
        chapters: Map.get(vd, :chapters, []), keywords: Map.get(vd, :keywords, [])} end)

    results = add_optional_result(results, video_data, :search_queries,
      &TrendingTopicAnalyzer.analyze/1, :trending_topics,
      fn vd -> %{search_queries: vd.search_queries, trending_data: Map.get(vd, :trending_data, %{}),
        channel_niche: Map.get(vd, :channel_niche, "general")} end)

    {:ok, results}
  end

  defp safe_analyze(fun, data) do
    case fun.(data) do
      {:ok, r} -> r
      {:error, _} -> %{}
    end
  end

  defp add_optional_result(results, video_data, key, fun, result_key, input_builder) do
    if Map.has_key?(video_data, key) do
      result =
        case fun.(input_builder.(video_data)) do
          {:ok, r} -> r
          {:error, _} -> %{}
        end
      Map.put(results, result_key, result)
    else
      results
    end
  end

  def analyze_video(_video_data, _options) do
    {:error, :invalid_input}
  end

  @doc """
  Analyzes video performance metrics.
  Delegates to PerformanceAnalytics.
  """
  def performance(video_data) when is_map(video_data) do
    PerformanceAnalytics.analyze(video_data)
  end

  def performance(_), do: {:error, :invalid_input}

  @doc """
  Analyzes audience engagement metrics.
  Delegates to AudienceEngagement.
  """
  def engagement(video_data) when is_map(video_data) do
    AudienceEngagement.analyze(video_data)
  end

  def engagement(_), do: {:error, :invalid_input}

  @doc """
  Generates content recommendations.
  Delegates to RecommendationEngine.
  """
  def recommendations(video_data) when is_map(video_data) do
    RecommendationEngine.recommend(video_data)
  end

  def recommendations(_), do: {:error, :invalid_input}

  @doc """
  Predicts optimal posting times.
  Delegates to PostingTimePredictor.
  """
  def posting_times(video_data) when is_map(video_data) do
    PostingTimePredictor.predict(video_data)
  end

  def posting_times(_), do: {:error, :invalid_input}

  @doc """
  Optimizes title and thumbnail.
  Delegates to TitleThumbnailOptimizer.
  """
  def title_thumbnail(video_data) when is_map(video_data) do
    TitleThumbnailOptimizer.optimize_title(video_data)
  end

  def title_thumbnail(_), do: {:error, :invalid_input}

  @doc """
  Generates video metadata (SEO description, chapters, tags).
  Delegates to MetadataGenerator.
  """
  def metadata(video_data) when is_map(video_data) do
    MetadataGenerator.generate(video_data)
  end

  def metadata(_), do: {:error, :invalid_input}

  @doc """
  Analyzes trending topics.
  Delegates to TrendingTopicAnalyzer.
  """
  def trending_topics(video_data) when is_map(video_data) do
    TrendingTopicAnalyzer.analyze(video_data)
  end

  def trending_topics(_), do: {:error, :invalid_input}

  @doc """
  Returns a summary of all available intelligence modules.
  """
  def modules do
    [
      %{name: "PerformanceAnalytics", module: Lux.YouTube.ContentIntelligence.PerformanceAnalytics,
        description: "Video performance analytics - view velocity, retention, drop detection"},
      %{name: "AudienceEngagement", module: Lux.YouTube.ContentIntelligence.AudienceEngagement,
        description: "Audience engagement analysis - loyalty scoring, traffic classification"},
      %{name: "RecommendationEngine", module: Lux.YouTube.ContentIntelligence.RecommendationEngine,
        description: "Content recommendation engine - topic generation, search gap discovery"},
      %{name: "PostingTimePredictor", module: Lux.YouTube.ContentIntelligence.PostingTimePredictor,
        description: "Optimal posting time prediction - heatmaps, timezone weighting"},
      %{name: "TitleThumbnailOptimizer", module: Lux.YouTube.ContentIntelligence.TitleThumbnailOptimizer,
        description: "Title and thumbnail optimization - CTR scoring, A/B variants"},
      %{name: "MetadataGenerator", module: Lux.YouTube.ContentIntelligence.MetadataGenerator,
        description: "Automated metadata generation - SEO description, chapters, tags"},
      %{name: "TrendingTopicAnalyzer", module: Lux.YouTube.ContentIntelligence.TrendingTopicAnalyzer,
        description: "Trending topic analysis - momentum scoring, saturation index"}
    ]
  end
end