defmodule Lux.YouTube.GrowthEngine.GrowthPredictorTest do
  use UnitCase, async: true

  alias Lux.YouTube.GrowthEngine.GrowthPredictor

  describe "forecast_growth/1" do
    test "computes 30d/60d/90d forecast and milestone ETAs" do
      params = %{
        current_subscribers: 20_000,
        daily_sub_velocity: 50.0,
        daily_view_velocity: 4_000.0,
        rpm: 5.0
      }

      forecast = GrowthPredictor.forecast_growth(params)

      assert forecast.current_subscribers == 20_000
      assert forecast.projected_30d.projected_subscribers > 20_000
      assert forecast.projected_60d.projected_subscribers > forecast.projected_30d.projected_subscribers
      assert forecast.projected_90d.projected_revenue_usd > 0.0

      # Check milestones
      achieved = Enum.filter(forecast.milestones, &(&1.status == :achieved))
      assert length(achieved) >= 4 # 1k, 5k, 10k achieved

      approaching = Enum.find(forecast.milestones, &(&1.milestone == 50_000))
      assert approaching.days_remaining > 0
    end
  end
end
