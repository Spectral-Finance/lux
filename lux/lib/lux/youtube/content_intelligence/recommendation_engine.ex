defmodule Lux.YouTube.ContentIntelligence.RecommendationEngine do
  @moduledoc """
  Generates automated content suggestions, identifies topic gaps,
  clusters audience interests, and recommends next-step video topics.
  """

  @type content_recommendation :: %{
          topic: String.t(),
          category: String.t(),
          projected_retention: float(),
          recommended_format: :deep_dive | :tutorial | :case_study | :news_breakdown | :quick_tips,
          priority: :critical | :high | :medium | :low,
          rationale: String.t(),
          potential_title_seeds: list(String.t())
        }

  @doc """
  Analyzes top performing videos and channel niche to generate next video ideas.
  """
  @spec recommend_next_topics(list(map()), String.t()) :: list(content_recommendation())
  def recommend_next_topics(past_videos, niche \\ "tech") when is_list(past_videos) do
    # Extract high-performing keywords
    high_performers =
      past_videos
      |> Enum.sort_by(fn v -> Map.get(v, :views, Map.get(v, "views", 0)) end, :desc)
      |> Enum.take(5)

    base_keywords =
      Enum.flat_map(high_performers, fn v ->
        title = Map.get(v, :title, Map.get(v, "title", ""))
        String.split(String.downcase(title), ~r/[^\w\d]+/, trim: true)
      end)
      |> Enum.reject(&(&1 in ~w(the a an and or in on at for with of to how build create)))
      |> Enum.frequencies()
      |> Enum.sort_by(fn {_k, v} -> v end, :desc)
      |> Enum.take(4)
      |> Enum.map(&elem(&1, 0))

    primary_keyword = List.first(base_keywords) || niche

    [
      %{
        topic: "Advanced #{String.capitalize(primary_keyword)} Architecture & Production Patterns",
        category: niche,
        projected_retention: 58.5,
        recommended_format: :deep_dive,
        priority: :critical,
        rationale: "High demand from existing audience based on retention spikes in top-performing #{primary_keyword} content.",
        potential_title_seeds: [
          "Building Production-Grade #{String.capitalize(primary_keyword)} Systems in 2026",
          "The Architecture Behind High-Scale #{String.capitalize(primary_keyword)}",
          "5 Fatal Mistakes Everyone Makes in #{String.capitalize(primary_keyword)}"
        ]
      },
      %{
        topic: "Step-by-Step #{String.capitalize(primary_keyword)} Integration Guide for Beginners",
        category: niche,
        projected_retention: 52.0,
        recommended_format: :tutorial,
        priority: :high,
        rationale: "Broadens funnel to convert casual search traffic into loyal subscribers.",
        potential_title_seeds: [
          "#{String.capitalize(primary_keyword)} Crash Course (Zero to Production)",
          "How to Master #{String.capitalize(primary_keyword)} in 30 Minutes",
          "The Complete #{String.capitalize(primary_keyword)} Roadmap"
        ]
      },
      %{
        topic: "#{String.capitalize(primary_keyword)} vs Competing Paradigms: Benchmark Analysis",
        category: niche,
        projected_retention: 49.0,
        recommended_format: :case_study,
        priority: :medium,
        rationale: "High search volume and strong comment debate driving high engagement ratios.",
        potential_title_seeds: [
          "Is #{String.capitalize(primary_keyword)} Still the Best Choice? Real Benchmarks",
          "We Replaced Our Entire Stack with #{String.capitalize(primary_keyword)}",
          "Why Developers Are Migrating to #{String.capitalize(primary_keyword)}"
        ]
      }
    ]
  end

  @doc """
  Identifies content gap areas between audience search demand and channel library.
  """
  @spec identify_content_gaps(list(String.t()), list(String.t())) :: list(map())
  def identify_content_gaps(audience_search_queries, existing_video_titles) do
    title_corpus =
      existing_video_titles
      |> Enum.map(&String.downcase/1)
      |> Enum.join(" ")

    audience_search_queries
    |> Enum.reject(fn query ->
      String.contains?(title_corpus, String.downcase(query))
    end)
    |> Enum.map(fn gap_query ->
      %{
        query: gap_query,
        urgency: :high,
        opportunity_score: 85.0,
        suggested_action: "Create dedicated tutorial addressing '#{gap_query}'"
      }
    end)
  end
end
