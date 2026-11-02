defmodule Lux.YouTube.GrowthEngine.ReportingSystemTest do
  use UnitCase, async: true

  alias Lux.YouTube.GrowthEngine.ReportingSystem

  describe "generate_executive_markdown/1" do
    test "compiles Markdown executive report with KPIs, grade, and ROI" do
      data = %{
        channel_name: "Lux Media",
        telemetry: %{
          views: 125_000,
          net_subscribers: 1_400,
          estimated_revenue_usd: 850.0,
          rpm: 6.8
        },
        audit: %{
          health_grade: :a,
          overall_score: 88.5,
          category_scores: %{ctr_performance: 90.0, cadence_consistency: 85.0}
        },
        forecast: %{
          projected_30d: %{projected_subscribers: 25_000, projected_revenue_usd: 1_200.0}
        },
        roi: %{
          roi_multiplier: 2.8,
          net_profit_usd: 550.0
        }
      }

      markdown = ReportingSystem.generate_executive_markdown(data)

      assert is_binary(markdown)
      assert String.contains?(markdown, "Lux Media")
      assert String.contains?(markdown, "Total Views:")
      assert String.contains?(markdown, "Blended RPM:")
      assert String.contains?(markdown, ":a")
      assert String.contains?(markdown, "Production ROI Multiplier:")
    end
  end
end
