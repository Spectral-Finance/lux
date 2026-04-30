defmodule Lux.Prisms.YoutubeAnalytics.GrowthPredictionPrismTest do
  use ExUnit.Case, async: true
  doctest Lux.Prisms.YoutubeAnalytics.GrowthPredictionPrism

  describe "transform/1" do
    test "has correct prism metadata" do
      assert Lux.Prisms.YoutubeAnalytics.GrowthPredictionPrism.__meta__(:name) == "YouTube Growth Prediction"
    end

    test "returns error with insufficient data" do
      assert {:error, _} = Lux.Prisms.YoutubeAnalytics.GrowthPredictionPrism.transform(%{
        historical_data: [%{date: "2024-01-01", subscriber_count: 1000, view_count: 5000}]
      })
    end

    test "generates predictions with valid data" do
      historical = [
        %{date: "2024-01-01", subscriber_count: 1000, view_count: 5000, video_count: 10},
        %{date: "2024-02-01", subscriber_count: 1500, view_count: 8000, video_count: 15},
        %{date: "2024-03-01", subscriber_count: 2000, view_count: 12000, video_count: 20}
      ]

      assert {:ok, result} = Lux.Prisms.YoutubeAnalytics.GrowthPredictionPrism.transform(%{
        historical_data: historical,
        prediction_days: 90
      })

      assert result.predictions != nil
      assert result.growth_rate != nil
      assert result.growth_rate.trend == "growing"
      assert result.confidence == 0.85
    end

    test "identifies milestones within prediction window" do
      historical = [
        %{date: "2024-01-01", subscriber_count: 500, view_count: 2000, video_count: 5},
        %{date: "2024-03-01", subscriber_count: 800, view_count: 4000, video_count: 10}
      ]

      assert {:ok, result} = Lux.Prisms.YoutubeAnalytics.GrowthPredictionPrism.transform(%{
        historical_data: historical,
        prediction_days: 365
      })

      assert length(result.milestones) > 0
    end
  end
end
