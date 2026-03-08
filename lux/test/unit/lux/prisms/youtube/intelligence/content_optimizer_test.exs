defmodule Lux.Prisms.YouTube.Intelligence.ContentOptimizerTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.YouTube.Intelligence.ContentOptimizer

  describe "optimize_title" do
    test "returns title suggestions and score" do
      assert {:ok, result} =
               ContentOptimizer.handler(
                 %{action: "optimize_title", title: "How to Learn Python Programming"},
                 []
               )

      assert result.original == "How to Learn Python Programming"
      assert length(result.suggestions) > 0
      assert result.score > 0
      assert is_list(result.tips)
    end

    test "scores short titles lower" do
      {:ok, short} = ContentOptimizer.handler(%{action: "optimize_title", title: "Python"}, [])
      {:ok, good} = ContentOptimizer.handler(%{action: "optimize_title", title: "How to Learn Python Programming in 2026 - Complete Beginner Guide"}, [])

      assert good.score > short.score
    end
  end

  describe "generate_tags" do
    test "generates tags from title and niche" do
      assert {:ok, result} =
               ContentOptimizer.handler(
                 %{
                   action: "generate_tags",
                   title: "Python Machine Learning Tutorial",
                   niche: "programming education",
                   description: "Learn ML with Python from scratch"
                 },
                 []
               )

      assert length(result.tags) > 0
      assert result.count > 0
      assert result.max_allowed == 30
    end

    test "respects max tag limit" do
      assert {:ok, result} =
               ContentOptimizer.handler(
                 %{
                   action: "generate_tags",
                   title: "a b c d e f g h i j k l m n o p q r s t u v w x y z",
                   tags: Enum.map(1..25, &"tag#{&1}")
                 },
                 []
               )

      assert result.count <= 30
    end
  end

  describe "optimize_description" do
    test "generates optimized description" do
      assert {:ok, result} =
               ContentOptimizer.handler(
                 %{
                   action: "optimize_description",
                   title: "Python Tutorial",
                   description: "Learn Python basics",
                   niche: "programming"
                 },
                 []
               )

      assert result.has_cta == true
      assert result.has_hashtags == true
      assert String.length(result.optimized_description) > 0
    end
  end

  describe "best_posting_time" do
    test "returns schedule for gaming niche" do
      assert {:ok, result} =
               ContentOptimizer.handler(%{action: "best_posting_time", niche: "gaming"}, [])

      assert "Friday" in result.best_days or "Saturday" in result.best_days
      assert length(result.best_hours) > 0
    end

    test "returns default schedule for unknown niche" do
      assert {:ok, result} =
               ContentOptimizer.handler(%{action: "best_posting_time", niche: "random stuff"}, [])

      assert length(result.best_days) > 0
    end
  end

  describe "full_optimization" do
    test "combines all optimizations" do
      assert {:ok, result} =
               ContentOptimizer.handler(
                 %{
                   action: "full_optimization",
                   title: "Learn Elixir Programming",
                   description: "Complete guide to Elixir",
                   niche: "programming",
                   tags: ["elixir", "functional"]
                 },
                 []
               )

      assert Map.has_key?(result, :title)
      assert Map.has_key?(result, :tags)
      assert Map.has_key?(result, :description)
      assert Map.has_key?(result, :posting_time)
      assert result.overall_score > 0
    end
  end
end
