defmodule Lux.Prisms.YouTube.AnalyzeGrowthTest do
  use UnitCase, async: true

  alias Lux.Prisms.YouTube.AnalyzeGrowth

  @input %{
    channel_name: "Operators Weekly",
    period_days: 14,
    videos: [
      %{
        title: "Treasury controls",
        views: 8_000,
        impressions: 100_000,
        average_view_duration_seconds: 210,
        duration_seconds: 420,
        subscribers_gained: 180,
        revenue_usd: 300,
        topics: ["treasury"],
        traffic_sources: %{"browse" => 0.5},
        audience: %{"US" => 0.45}
      }
    ]
  }

  test "runs the YouTube growth engine through the prism" do
    assert {:ok, report} = AnalyzeGrowth.run(@input)

    assert report.analytics_data_collection.totals.views == 8_000
    assert report.growth_prediction.projected_views > 0
    assert report.revenue_optimization.current_revenue_usd == 300
    assert report.automated_report.title == "Operators Weekly growth report"
  end

  test "exposes input and output schemas" do
    prism = AnalyzeGrowth.view()

    assert prism.name == "Analyze YouTube Growth"
    assert prism.input_schema.required == ["videos"]

    assert prism.output_schema.required == [
             "analytics_data_collection",
             "audience_insights",
             "growth_prediction",
             "revenue_optimization",
             "channel_audit",
             "automated_report"
           ]
  end
end
