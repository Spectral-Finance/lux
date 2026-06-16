defmodule Lux.Prisms.YouTube.GenerateGrowthReportTest do
  use UnitCase, async: true

  alias Lux.Prisms.YouTube.GenerateGrowthReport

  test "wraps the YouTube growth report in a prism response" do
    snapshots = [
      %{
        id: "video-1",
        captured_at: "2026-06-01T00:00:00Z",
        views: 100,
        impressions: 1_000,
        clicks: 50
      },
      %{
        id: "video-1",
        captured_at: "2026-06-08T00:00:00Z",
        views: 200,
        impressions: 1_500,
        clicks: 90
      }
    ]

    assert {:ok, %{report: report}} =
             GenerateGrowthReport.handler(%{snapshots: snapshots, horizon_days: 7}, nil)

    assert report.analytics_data.total_videos == 1
    assert report.growth_prediction["video-1"].projected_views == 300
  end
end
