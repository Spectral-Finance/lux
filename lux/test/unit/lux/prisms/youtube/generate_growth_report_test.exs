defmodule Lux.Prisms.YouTube.GenerateGrowthReportTest do
  @moduledoc """
  Test suite for the YouTube GenerateGrowthReport prism.
  Verifies:
  - Full monthly report with all sections populated
  - Weekly and quarterly period variants
  - Revenue estimates are non-negative
  - Handles channel_id being optional
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.YouTube.GenerateGrowthReport

  @agent_ctx %{agent: %{name: "TestAgent"}}

  @base_stats %{
    "subscriber_count" => 75_000,
    "view_count" => 5_000_000,
    "video_count" => 220,
    "avg_views_per_video" => 22_727
  }

  describe "handler/2" do
    test "generates a complete monthly growth report" do
      assert {:ok, report} = GenerateGrowthReport.handler(
        %{
          "channel_id" => "UCxxxxxx",
          "channel_stats" => @base_stats,
          "time_period" => "monthly"
        },
        @agent_ctx
      )

      assert report.channel_id == "UCxxxxxx"
      assert report.time_period == "monthly"
      assert is_binary(report.executive_summary)
      assert String.length(report.executive_summary) > 20

      assert is_map(report.key_metrics)
      assert report.key_metrics.subscriber_count == 75_000
      assert report.key_metrics.total_views == 5_000_000

      assert is_map(report.growth_rate)
      assert report.growth_rate.estimated_monthly_growth_percent > 0
      assert is_integer(report.growth_rate.projected_subscribers)
      assert report.growth_rate.projected_subscribers >= 75_000

      assert is_map(report.revenue_estimates)
      assert report.revenue_estimates.estimated_revenue_usd.low >= 0
      assert report.revenue_estimates.estimated_revenue_usd.high >= report.revenue_estimates.estimated_revenue_usd.low

      assert is_list(report.recommendations)
      assert length(report.recommendations) >= 3

      assert is_list(report.next_steps)
      assert length(report.next_steps) >= 1
    end

    test "generates a weekly growth report" do
      assert {:ok, report} = GenerateGrowthReport.handler(
        %{
          "channel_stats" => @base_stats,
          "time_period" => "weekly"
        },
        @agent_ctx
      )

      assert report.time_period == "weekly"
      assert report.growth_rate.period == "weekly"
      assert report.channel_id == nil
    end

    test "generates a quarterly growth report" do
      assert {:ok, report} = GenerateGrowthReport.handler(
        %{
          "channel_stats" => @base_stats,
          "time_period" => "quarterly"
        },
        @agent_ctx
      )

      assert report.time_period == "quarterly"
      assert report.growth_rate.period == "quarterly"
      assert report.revenue_estimates.estimated_revenue_usd.high >= 0
    end

    test "defaults time_period to monthly when not provided" do
      assert {:ok, report} = GenerateGrowthReport.handler(
        %{"channel_stats" => @base_stats},
        @agent_ctx
      )

      assert report.time_period == "monthly"
    end

    test "handles very small channel without errors" do
      assert {:ok, report} = GenerateGrowthReport.handler(
        %{
          "channel_stats" => %{
            "subscriber_count" => 100,
            "view_count" => 5_000,
            "video_count" => 10
          },
          "time_period" => "monthly"
        },
        @agent_ctx
      )

      assert report.key_metrics.subscriber_count == 100
      assert report.revenue_estimates.estimated_revenue_usd.low >= 0
    end
  end
end
