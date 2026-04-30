defmodule Lux.Prisms.YoutubeAnalytics.PerformanceBenchmarkPrismTest do
  use ExUnit.Case, async: true
  doctest Lux.Prisms.YoutubeAnalytics.PerformanceBenchmarkPrism

  describe "transform/1" do
    test "has correct prism metadata" do
      assert Lux.Prisms.YoutubeAnalytics.PerformanceBenchmarkPrism.__meta__(:name) == "YouTube Performance Benchmark"
    end

    test "benchmarks channel against category" do
      assert {:ok, result} = Lux.Prisms.YoutubeAnalytics.PerformanceBenchmarkPrism.transform(%{
        channel_metrics: %{
          subscriber_count: 10000,
          view_count: 100000,
          video_count: 20,
          avg_views_per_video: 5000,
          engagement_rate: 3.5
        },
        category: "technology"
      })

      assert result.benchmarks != nil
      assert result.percentile_rankings != nil
      assert result.gaps != nil
      assert result.strengths != nil
      assert result.improvement_areas != nil
    end

    test "identifies strengths when above benchmark" do
      assert {:ok, result} = Lux.Prisms.YoutubeAnalytics.PerformanceBenchmarkPrism.transform(%{
        channel_metrics: %{
          subscriber_count: 50000,
          avg_views_per_video: 20000,
          engagement_rate: 6.0
        },
        category: "general"
      })
      assert length(result.strengths) > 0
    end

    test "identifies improvement areas when below benchmark" do
      assert {:ok, result} = Lux.Prisms.YoutubeAnalytics.PerformanceBenchmarkPrism.transform(%{
        channel_metrics: %{
          subscriber_count: 100,
          avg_views_per_video: 500,
          engagement_rate: 0.5
        },
        category: "general"
      })
      assert length(result.improvement_areas) > 0
    end
  end
end
