defmodule Lux.YouTube.ContentIntelligence.RecommendationEngineTest do
  use UnitCase, async: true

  alias Lux.YouTube.ContentIntelligence.RecommendationEngine

  describe "recommend_next_topics/2" do
    test "recommends relevant video topics based on past top performers" do
      past_videos = [
        %{title: "Building Microservices with Elixir OTP", views: 45_000},
        %{title: "Elixir OTP GenServer Deep Dive", views: 38_000},
        %{title: "Intro to CSS", views: 2_000}
      ]

      recommendations = RecommendationEngine.recommend_next_topics(past_videos, "elixir")

      assert length(recommendations) >= 3
      first = List.first(recommendations)
      assert is_binary(first.topic)
      assert first.projected_retention > 40.0
      assert length(first.potential_title_seeds) >= 2
    end
  end

  describe "identify_content_gaps/2" do
    test "identifies uncovered audience search queries" do
      queries = ["elixir rust ffi", "distributed supervision trees", "graphql setup"]
      existing_titles = ["Distributed Supervision Trees Guide", "Beginner Guide"]

      gaps = RecommendationEngine.identify_content_gaps(queries, existing_titles)

      assert length(gaps) == 2
      gap_queries = Enum.map(gaps, & &1.query)
      assert "elixir rust ffi" in gap_queries
      assert "graphql setup" in gap_queries
      refute "distributed supervision trees" in gap_queries
    end
  end
end
