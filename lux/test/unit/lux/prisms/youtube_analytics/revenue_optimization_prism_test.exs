defmodule Lux.Prisms.YoutubeAnalytics.RevenueOptimizationPrismTest do
  use ExUnit.Case, async: true
  doctest Lux.Prisms.YoutubeAnalytics.RevenueOptimizationPrism

  describe "transform/1" do
    test "has correct prism metadata" do
      assert Lux.Prisms.YoutubeAnalytics.RevenueOptimizationPrism.__meta__(:name) == "YouTube Revenue Optimization"
    end

    test "returns error with no revenue data" do
      assert {:error, _} = Lux.Prisms.YoutubeAnalytics.RevenueOptimizationPrism.transform(%{revenue_data: []})
    end

    test "analyzes revenue data correctly" do
      revenue_data = [
        %{date: "2024-01-01", estimated_revenue: 100.0, views: 1000, cpm: 5.0},
        %{date: "2024-02-01", estimated_revenue: 150.0, views: 1500, cpm: 5.5},
        %{date: "2024-03-01", estimated_revenue: 200.0, views: 2000, cpm: 6.0}
      ]

      assert {:ok, result} = Lux.Prisms.YoutubeAnalytics.RevenueOptimizationPrism.transform(%{
        revenue_data: revenue_data
      })

      assert result.revenue_analysis.total_revenue == 450.0
      assert result.recommendations != nil
      assert result.optimization_score != nil
    end

    test "generates recommendations based on CPM" do
      revenue_data = [
        %{date: "2024-01-01", estimated_revenue: 50.0, views: 1000, cpm: 2.0},
        %{date: "2024-02-01", estimated_revenue: 60.0, views: 1200, cpm: 2.5}
      ]

      assert {:ok, result} = Lux.Prisms.YoutubeAnalytics.RevenueOptimizationPrism.transform(%{
        revenue_data: revenue_data
      })

      high_priority = Enum.filter(result.recommendations, &(&1.priority == "high"))
      assert length(high_priority) > 0
    end
  end
end
