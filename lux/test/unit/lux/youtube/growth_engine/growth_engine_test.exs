defmodule Lux.YouTube.GrowthEngineTest do
  use UnitCase, async: true

  alias Lux.YouTube.GrowthEngine

  describe "conduct_executive_audit/2" do
    test "runs full growth audit with telemetry, competitor benchmark, forecasting, and markdown report" do
      channel_data = %{
        channel_name: "Lux Autonomous Systems",
        niche: "ai",
        views: 80_000,
        watch_time_seconds: 28_800_000.0,
        subscribers_gained: 1_200,
        subscribers_lost: 100,
        impressions: 1_000_000,
        clicks: 55_000,
        estimated_revenue_usd: 560.0,
        current_subscribers: 35_000,
        daily_sub_velocity: 40.0,
        daily_view_velocity: 3_000.0,
        average_ctr: 5.5,
        uploads_per_month: 4,
        production_costs: %{
          video_editing_usd: 200.0,
          thumbnail_design_usd: 50.0
        }
      }

      competitors = [
        %{
          channel_name: "Competing AI Hub",
          monthly_views: 120_000,
          monthly_uploads: 6,
          subscribers: 50_000,
          breakout_topics: ["Agent Swarms", "MCP Servers"]
        }
      ]

      result = GrowthEngine.conduct_executive_audit(channel_data, competitors)

      assert result.status == :audit_complete
      assert result.channel_name == "Lux Autonomous Systems"
      assert result.telemetry.views == 80_000
      assert result.telemetry.rpm == 7.0
      assert result.competitors.market_share_percentage == 40.0
      assert result.forecast.projected_30d.projected_subscribers > 35_000
      assert result.roi.is_profitable == true
      assert is_binary(result.executive_markdown_report)
    end
  end
end
