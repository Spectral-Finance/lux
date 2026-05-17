defmodule Lux.Prisms.YouTube.AnalyzeGrowthTest do
  use UnitCase, async: true

  alias Lux.Prisms.YouTube.AnalyzeGrowth

  describe "handler/2" do
    test "returns a full growth report for agents" do
      {:ok, report} =
        AnalyzeGrowth.run(%{
          channel_series: [
            %{views: 1_000, subscribers: 100, revenue: 80, cost: 40},
            %{
              views: 1_500,
              subscribers: 130,
              revenue: 120,
              cost: 60,
              average_view_duration_seconds: 180,
              video_duration_seconds: 300
            }
          ],
          competitors: [%{views: 1_200, likes: 30, comments: 10, shares: 5}],
          forecast_periods: 2,
          target_rpm: 100
        })

      assert report.summary.view_growth_rate == 0.5
      assert length(report.forecast) == 2
      assert report.revenue_optimization.incremental_revenue > 0
      assert is_list(report.recommendations)
    end

    test "accepts string keyed input" do
      {:ok, report} =
        AnalyzeGrowth.run(%{
          "channel_series" => [
            %{"views" => 100, "subscribers" => 10, "revenue" => 10},
            %{"views" => 200, "subscribers" => 20, "revenue" => 20}
          ],
          "forecast_periods" => 1
        })

      assert [%{period: 1}] = report.forecast
    end
  end
end
