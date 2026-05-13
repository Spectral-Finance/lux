defmodule Lux.Integrations.YouTube.GrowthEngineTest do
  use UnitCase, async: true

  alias Lux.Integrations.YouTube.GrowthEngine

  @brief %{
    channel_name: "DeFi Operators",
    period_days: 28,
    production_cost_usd: 1_800,
    goals: %{views: 50_000, subscribers: 1_000, revenue_usd: 1_500},
    videos: [
      %{
        title: "Stablecoin risk checklist",
        published_at: "2026-04-05",
        views: 10_000,
        impressions: 200_000,
        average_view_duration_seconds: 240,
        duration_seconds: 600,
        subscribers_gained: 160,
        revenue_usd: 250,
        topics: ["stablecoins", "risk"],
        traffic_sources: %{"browse" => 0.38, "search" => 0.32},
        audience: %{"US" => 0.4, "SG" => 0.2}
      },
      %{
        title: "DeFi treasury dashboard",
        published_at: "2026-04-19",
        views: 18_000,
        impressions: 260_000,
        average_view_duration_seconds: 360,
        duration_seconds: 720,
        subscribers_gained: 420,
        revenue_usd: 640,
        topics: ["treasury", "risk"],
        traffic_sources: %{"browse" => 0.5, "search" => 0.22},
        audience: %{"US" => 0.48, "UK" => 0.16}
      },
      %{
        title: "Protocol revenue teardown",
        published_at: "2026-05-03",
        views: 24_000,
        impressions: 300_000,
        average_view_duration_seconds: 420,
        duration_seconds: 700,
        subscribers_gained: 610,
        revenue_usd: 900,
        topics: ["revenue", "treasury", "risk"],
        traffic_sources: %{"browse" => 0.54, "external" => 0.18},
        audience: %{"US" => 0.44, "DE" => 0.14}
      }
    ],
    competitors: [
      %{channel: "Protocol Brief", views: 42_000, subscribers_gained: 640, upload_count: 4},
      %{channel: "Onchain Ops", views: 36_000, subscribers_gained: 500, upload_count: 3}
    ]
  }

  describe "run/1" do
    test "builds a complete analytics and growth report" do
      assert {:ok, report} = GrowthEngine.run(@brief)

      assert report.channel_name == "DeFi Operators"
      assert report.analytics_data_collection.totals.views == 52_000
      assert report.analytics_data_collection.totals.subscribers_gained == 1_190
      assert report.analytics_data_collection.rates.weighted_ctr == 0.0684
      assert report.audience_insights.primary_topic == "risk"
      assert report.trend_analysis.direction == "up"
      assert report.growth_prediction.projected_views > 52_000
      assert report.revenue_optimization.current_rpm > 0
      assert report.retention_analysis.average_retention_rate > 0.45
      assert report.competitor_analysis.competitor_count == 2
      assert report.roi_tracking.payback_status == "below_payback"
      assert report.channel_audit.grade in ["A", "B", "C", "D"]

      assert "Refresh ROI and revenue gap after each reporting period" in report.channel_audit.recurring_checks

      assert "Analytics data collection" in report.automated_report.next_report_sections
      assert "Channel audit" in report.automated_report.next_report_sections
      assert length(report.experiments) == 3
      assert length(report.action_plan) == 4
    end

    test "accepts string-keyed analytics exports" do
      brief = %{
        "channel_name" => "String Keys",
        "videos" => [
          %{
            "title" => "Search growth",
            "views" => "12000",
            "impressions" => "120000",
            "average_view_duration_seconds" => "180",
            "duration_seconds" => "360",
            "subscribers_gained" => "240",
            "revenue_usd" => "480",
            "topics" => ["search"],
            "traffic_sources" => %{"search" => 0.7},
            "audience" => %{"US" => 0.5}
          }
        ]
      }

      assert {:ok, report} = GrowthEngine.run(brief)
      assert report.channel_name == "String Keys"
      assert report.analytics_data_collection.totals.views == 12_000
      assert report.analytics_data_collection.rates.rpm == 40.0
      assert report.audience_insights.primary_traffic_source == "search"
    end

    test "rejects non-map input" do
      assert {:error, "Expected a map with YouTube analytics data"} = GrowthEngine.run([])
    end
  end

  describe "component reports" do
    test "collects metrics for reporting dashboards" do
      metrics = GrowthEngine.collect_metrics(@brief)

      assert metrics.upload_count == 3
      assert metrics.data_quality.status == "complete"
      assert hd(metrics.top_videos).title == "Protocol revenue teardown"
    end

    test "builds revenue, retention, and competitor recommendations" do
      assert %{priority: "scale", opportunities: [_ | _]} =
               GrowthEngine.revenue_optimization(@brief)

      assert %{recommendations: [_ | _]} = GrowthEngine.retention_optimization(@brief)
      assert %{recommendations: [_ | _]} = GrowthEngine.competitive_benchmark(@brief)
      assert %{score: score, recurring_checks: [_ | _]} = GrowthEngine.channel_audit(@brief)
      assert score > 0
    end
  end
end
