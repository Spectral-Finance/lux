defmodule Lux.YouTube.GrowthEngine.RevenueOptimizerTest do
  use UnitCase, async: true

  alias Lux.YouTube.GrowthEngine.RevenueOptimizer

  describe "plan_midroll_placements/2" do
    test "recommends optimal timestamps for videos >= 8 minutes" do
      rec = RevenueOptimizer.plan_midroll_placements(600)

      assert rec.eligible_for_midrolls == true
      assert length(rec.recommended_ad_timestamps) == 2
      assert rec.projected_rpm_lift_percentage > 0.0
    end

    test "flags videos under 8 minutes as ineligible" do
      rec = RevenueOptimizer.plan_midroll_placements(300)

      assert rec.eligible_for_midrolls == false
      assert rec.recommended_ad_timestamps == []
    end
  end

  describe "calculate_sponsorship_rates/3" do
    test "computes fair rates factoring in niche multipliers" do
      rates = RevenueOptimizer.calculate_sponsorship_rates(25_000, "ai", 30.0)

      assert rates.niche == "ai"
      assert rates.niche_multiplier == 1.8
      assert rates.recommended_rates.integrated_60s > 1000.0
      assert rates.recommended_rates.dedicated_video > rates.recommended_rates.integrated_60s
      assert rates.recommended_rates.shoutout_30s < rates.recommended_rates.integrated_60s
    end
  end
end
