defmodule Lux.Integration.YouTubeGrowthEngineTest do
  use IntegrationCase, async: true

  alias Lux.Prisms.YouTube.AnalyzeGrowth

  @moduletag :integration

  test "collects analytics data and generates an automated growth report" do
    assert {:ok, report} =
             AnalyzeGrowth.run(%{
               channel_name: "Protocol Growth Lab",
               period_days: 28,
               production_cost_usd: 900,
               goals: %{views: 40_000, subscribers: 800, revenue_usd: 1_200},
               videos: [
                 %{
                   title: "Bridge risk walkthrough",
                   published_at: "2026-04-15",
                   views: 9_000,
                   impressions: 180_000,
                   average_view_duration_seconds: 250,
                   duration_seconds: 500,
                   subscribers_gained: 190,
                   revenue_usd: 280,
                   topics: ["bridges", "risk"],
                   traffic_sources: %{"browse" => 0.42, "search" => 0.31},
                   audience: %{"US" => 0.42, "SG" => 0.2}
                 },
                 %{
                   title: "Yield strategy audit",
                   published_at: "2026-05-01",
                   views: 16_000,
                   impressions: 220_000,
                   average_view_duration_seconds: 340,
                   duration_seconds: 620,
                   subscribers_gained: 380,
                   revenue_usd: 610,
                   topics: ["yield", "risk"],
                   traffic_sources: %{"browse" => 0.5, "external" => 0.2},
                   audience: %{"US" => 0.46, "UK" => 0.14}
                 }
               ],
               competitors: [
                 %{
                   channel: "DeFi Benchmarks",
                   views: 30_000,
                   subscribers_gained: 450,
                   upload_count: 3
                 }
               ]
             })

    assert report.analytics_data_collection.totals.views == 25_000
    assert report.analytics_data_collection.rates.weighted_ctr > 0
    assert report.growth_prediction.projected_revenue_usd > 0
    assert report.revenue_optimization.revenue_gap_usd > 0

    assert report.channel_audit.recommended_focus in [
             "analytics_collection",
             "packaging",
             "retention",
             "monetization",
             "competitive_positioning",
             "scale_current_growth_system"
           ]

    assert report.automated_report.summary |> Enum.join(" ") =~ "Projected"
    assert "Competitor benchmark" in report.automated_report.next_report_sections
  end
end
