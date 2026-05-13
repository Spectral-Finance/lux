defmodule Lux.Integrations.YouTube.GrowthEngineTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.YouTube.GrowthEngine

  @snapshot %{
    captured_at: "2026-05-13",
    views: 1_000,
    watch_time_hours: 80,
    subscribers: 120,
    revenue: 25.0,
    impressions: 5_000,
    clicks: 250,
    likes: 20,
    comments: 10
  }

  describe "snapshot/1" do
    test "normalizes derived analytics metrics" do
      snapshot = GrowthEngine.snapshot(@snapshot)

      assert snapshot.ctr == 0.05
      assert snapshot.engagement_rate == 0.03
      assert snapshot.revenue_per_1k_views == 25.0
    end
  end

  describe "growth_projection/2" do
    test "projects future metrics from historical deltas" do
      projection =
        GrowthEngine.growth_projection(
          [
            Map.merge(@snapshot, %{captured_at: "2026-05-12", views: 1_000, subscribers: 100, revenue: 20.0}),
            Map.merge(@snapshot, %{captured_at: "2026-05-13", views: 1_300, subscribers: 130, revenue: 26.0})
          ],
          7
        )

      assert projection.views == 3_400
      assert projection.subscribers == 340
      assert projection.revenue == 68.0
    end
  end

  describe "competitor_benchmark/2" do
    test "calculates gaps against competitor averages" do
      benchmark =
        GrowthEngine.competitor_benchmark(@snapshot, [
          Map.merge(@snapshot, %{views: 800, clicks: 80, impressions: 2_000}),
          Map.merge(@snapshot, %{views: 1_200, clicks: 120, impressions: 3_000})
        ])

      assert benchmark.competitor_average.views == 1_000.0
      assert benchmark.gaps.views == 0.0
      assert_in_delta benchmark.gaps.ctr, 0.01, 0.0001
    end
  end

  describe "retention_summary/1" do
    test "summarizes retention and first drop" do
      summary =
        GrowthEngine.retention_summary([
          %{second: 0, retained_ratio: 1.0},
          %{second: 30, retained_ratio: 0.72},
          %{second: 60, retained_ratio: 0.48}
        ])

      assert_in_delta summary.average_retention, 0.7333333333333334, 0.0001
      assert summary.first_drop_second == 60
      assert summary.sample_count == 3
    end
  end

  describe "roi_summary/1" do
    test "calculates profit and ROI" do
      roi =
        GrowthEngine.roi_summary(%{
          revenue: 500,
          production_cost: 200,
          promotion_cost: 50
        })

      assert roi.total_cost == 250
      assert roi.profit == 250
      assert roi.roi == 1.0
    end
  end

  describe "audit/1" do
    test "returns channel health findings" do
      findings =
        GrowthEngine.audit(
          Map.merge(@snapshot, %{
            clicks: 10,
            likes: 5,
            comments: 1,
            revenue: 0.5,
            watch_time_hours: 2
          })
        )

      assert Enum.any?(findings, &(&1.area == :ctr and &1.severity == :high))
      assert Enum.any?(findings, &(&1.area == :engagement))
      assert Enum.any?(findings, &(&1.area == :revenue))
      assert Enum.any?(findings, &(&1.area == :watch_time))
    end
  end

  describe "report/1" do
    test "builds a full growth report" do
      generated_at = ~U[2026-05-13 00:00:00Z]

      report =
        GrowthEngine.report(%{
          generated_at: generated_at,
          channel_id: "channel-1",
          snapshots: [@snapshot],
          competitors: [Map.merge(@snapshot, %{views: 900})],
          retention_points: [%{second: 0, retained_ratio: 1.0}],
          roi: %{revenue: 100, production_cost: 40, promotion_cost: 10}
        })

      assert report.generated_at == generated_at
      assert report.channel_id == "channel-1"
      assert report.latest_snapshot.views == 1_000
      assert report.benchmark.competitor_average.views == 900.0
      assert report.roi.profit == 50
    end
  end
end
