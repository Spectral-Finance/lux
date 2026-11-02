defmodule Lux.YouTube.GrowthEngine.RoiTrackerTest do
  use UnitCase, async: true

  alias Lux.YouTube.GrowthEngine.RoiTracker

  describe "calculate_roi/3" do
    test "correctly assesses profit, ROI multiplier, and profit margin" do
      costs = %{
        scriptwriting_usd: 150.0,
        video_editing_usd: 250.0,
        thumbnail_design_usd: 50.0,
        voiceover_or_talent_usd: 0.0,
        tooling_and_hosting_usd: 50.0
      }
      revenue = 1_500.0

      roi = RoiTracker.calculate_roi("video_101", costs, revenue)

      assert roi.video_or_campaign_id == "video_101"
      assert roi.total_production_cost_usd == 500.0
      assert roi.total_gross_revenue_usd == 1_500.0
      assert roi.net_profit_usd == 1_000.0
      assert roi.roi_multiplier == 3.0
      assert roi.profit_margin_percentage == 66.67
      assert roi.is_profitable == true
      assert roi.breakeven_status == :profitable
    end
  end
end
