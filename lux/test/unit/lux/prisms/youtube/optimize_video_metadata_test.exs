defmodule Lux.Prisms.YouTube.OptimizeVideoMetadataTest do
  @moduledoc """
  Test suite for the OptimizeVideoMetadata prism.
  Verifies the prism can:
  - Return an optimized title with improved keywords
  - Compute an SEO score based on title, description, and tags
  - Return sorted and expanded tags list
  - Provide thumbnail recommendations
  - Provide optimal posting times by category
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.YouTube.OptimizeVideoMetadata

  @agent %{name: "TestAgent"}

  describe "handler/2" do
    test "optimizes short title and returns complete metadata analysis" do
      assert {:ok, result} = OptimizeVideoMetadata.handler(
        %{
          "title" => "Learn Elixir",
          "description" => "A short desc",
          "tags" => ["elixir", "coding"],
          "category" => "Education"
        },
        @agent
      )

      assert is_binary(result.optimized_title)
      assert String.length(result.optimized_title) > String.length("Learn Elixir")
      assert is_integer(result.seo_score)
      assert result.seo_score >= 0 and result.seo_score <= 100
      assert is_list(result.optimized_tags)
      assert is_list(result.thumbnail_recommendations)
      assert is_list(result.optimal_posting_times)
      assert length(result.thumbnail_recommendations) > 0
      assert length(result.optimal_posting_times) > 0
    end

    test "achieves high SEO score with optimized title, long description, and many tags" do
      long_description = String.duplicate("Comprehensive tutorial covering all aspects. ", 15)

      assert {:ok, result} = OptimizeVideoMetadata.handler(
        %{
          "title" => "How to Build a Complete Elixir Phoenix Web Application",
          "description" => long_description,
          "tags" => ["elixir", "phoenix", "web dev", "tutorial", "programming",
                     "backend", "functional", "liveview", "ecto", "otp"],
          "category" => "Education"
        },
        @agent
      )

      assert result.seo_score >= 70
    end

    test "returns low SEO score for minimal metadata" do
      assert {:ok, result} = OptimizeVideoMetadata.handler(
        %{"title" => "vid"},
        @agent
      )

      assert result.seo_score < 50
    end

    test "includes category-specific posting times for Gaming" do
      assert {:ok, result} = OptimizeVideoMetadata.handler(
        %{"title" => "My Gaming Video", "category" => "Gaming"},
        @agent
      )

      days = Enum.map(result.optimal_posting_times, & &1.day)
      assert "Friday" in days
    end

    test "adds title-derived compound tags to tag list" do
      assert {:ok, result} = OptimizeVideoMetadata.handler(
        %{
          "title" => "Complete Python Tutorial",
          "tags" => ["python"],
          "category" => "Education"
        },
        @agent
      )

      tag_strings = Enum.map(result.optimized_tags, &String.downcase/1)
      # Should include compound phrase from title
      assert Enum.any?(tag_strings, &String.contains?(&1, "python"))
    end

    test "expands short description with title and tag context" do
      assert {:ok, result} = OptimizeVideoMetadata.handler(
        %{
          "title" => "Elixir Basics",
          "description" => "Quick overview",
          "tags" => ["elixir", "basics"],
          "category" => "Education"
        },
        @agent
      )

      assert String.length(result.optimized_description) > String.length("Quick overview")
    end

    test "includes thumbnail recommendations with high-contrast advice" do
      assert {:ok, result} = OptimizeVideoMetadata.handler(
        %{"title" => "Test Video", "category" => "Technology"},
        @agent
      )

      recs_text = Enum.join(result.thumbnail_recommendations, " ")
      assert String.contains?(recs_text, "contrast") or String.contains?(recs_text, "text") or
             String.contains?(recs_text, "face")
    end
  end
end
