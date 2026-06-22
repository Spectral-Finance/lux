defmodule Lux.Prisms.YouTubePrismsTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.YouTube.GrowthPredictorPrism
  alias Lux.Prisms.YouTube.RevenueOptimizerPrism
  alias Lux.Prisms.YouTube.ReportGeneratorPrism

  describe "GrowthPredictorPrism" do
    test "predicts future subscribers accurately" do
      {:ok, result} = GrowthPredictorPrism.run(%{
        current_subscribers: 1000,
        historical_growth_rate: 0.10,
        months_to_predict: 3
      })

      assert result.predicted_subscribers == 1331
      assert length(result.growth_trajectory) == 3
      assert result.growth_trajectory == [1100, 1210, 1331]
    end
  end

  describe "RevenueOptimizerPrism" do
    test "calculates estimated and optimized revenue" do
      {:ok, result} = RevenueOptimizerPrism.run(%{
        views: 100_000,
        cpm: 5.0
      })

      assert result.estimated_revenue_usd == 500.0
      assert result.optimized_revenue_usd == 625.0
      assert length(result.optimization_strategies) == 4
    end
  end

  describe "ReportGeneratorPrism" do
    test "generates a markdown report" do
      {:ok, result} = ReportGeneratorPrism.run(%{
        channel_name: "Test Channel",
        stats: %{
          views: 5000,
          subscribers: 100,
          videos: 10
        },
        predicted_subscribers: 150,
        estimated_revenue_usd: 25.0
      })

      report = result.report_markdown
      assert report =~ "Test Channel"
      assert report =~ "Subscribers**: 100"
      assert report =~ "Predicted Subscribers (12 months)**: 150"
      assert report =~ "Estimated Revenue**: $25.0"
    end
  end
end
