defmodule Lux.Integrations.Telegram.Analytics.ReportGeneratorTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.Analytics.ReportGenerator

  describe "ReportGenerator" do
    test "generates markdown and html reports" do
      analytics = %{
        messages: %{total_messages: 500, messages_per_hour: 45.5},
        engagement: %{unique_active_users: 120},
        commands: %{
          total_command_invocations: 250,
          commands: [%{command: "swap", invocations: 150}, %{command: "help", invocations: 50}]
        },
        performance: %{
          error_rate_percent: 0.8,
          latency: %{p50: 120, p95: 350},
          rate_limit_429_count: 0,
          alerts: []
        }
      }

      md = ReportGenerator.generate_markdown_report(analytics)
      assert String.contains?(md, "Telegram Bot Analytics & Performance Report")
      assert String.contains?(md, "Total Messages: `500`")
      assert String.contains?(md, "Error Rate: `0.8%`")
      assert String.contains?(md, "swap")

      html = ReportGenerator.generate_html_report(analytics)
      assert String.contains?(html, "<b>Telegram Bot Analytics Report</b>")
      assert String.contains?(html, "<code>500</code>")
    end

    test "renders ascii bar charts, sparklines, and progress bars" do
      chart = ReportGenerator.ascii_bar_chart([{"swap", 100}, {"help", 50}], 10)
      assert String.contains?(chart, "swap")
      assert String.contains?(chart, "█")

      spark = ReportGenerator.sparkline([1, 2, 5, 8, 3])
      assert String.length(spark) > 0

      bar = ReportGenerator.progress_bar(75.5, 10)
      assert String.contains?(bar, "■")
      assert String.contains?(bar, "75.5%")
    end
  end
end
