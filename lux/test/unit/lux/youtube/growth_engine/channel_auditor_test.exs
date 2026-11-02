defmodule Lux.YouTube.GrowthEngine.ChannelAuditorTest do
  use UnitCase, async: true

  alias Lux.YouTube.GrowthEngine.ChannelAuditor

  describe "audit_channel/1" do
    test "scores healthy channel with grade A or A+" do
      channel_data = %{
        channel_name: "Lux Engineering",
        average_ctr: 5.8,
        uploads_per_month: 6,
        custom_thumbnails_ratio: 1.0,
        chapters_present_ratio: 0.95,
        sub_conversion_rate: 22.0
      }

      report = ChannelAuditor.audit_channel(channel_data)

      assert report.channel_name == "Lux Engineering"
      assert report.overall_score >= 80.0
      assert report.health_grade in [:a, :a_plus]
      assert report.category_scores.ctr_performance > 80.0
    end

    test "identifies critical issues for low CTR and irregular cadence" do
      channel_data = %{
        channel_name: "Struggling Tech",
        average_ctr: 2.1,
        uploads_per_month: 1,
        custom_thumbnails_ratio: 0.5,
        chapters_present_ratio: 0.2,
        sub_conversion_rate: 4.0
      }

      report = ChannelAuditor.audit_channel(channel_data)

      assert report.health_grade == :f
      assert length(report.critical_issues) >= 3
      assert length(report.quick_wins) >= 3
    end
  end
end
