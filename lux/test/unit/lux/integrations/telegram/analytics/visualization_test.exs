defmodule Lux.Integrations.Telegram.Analytics.VisualizationTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias Lux.Integrations.Telegram.Analytics.Visualization

  describe "bar_chart/2" do
    test "generates a basic bar chart" do
      data = %{a: 5, b: 10, c: 3}
      chart = Visualization.bar_chart(data, title: "Test Chart")

      assert String.contains?(chart, "Test Chart")
      assert String.contains?(chart, "█")
      assert String.contains?(chart, "(5)")
      assert String.contains?(chart, "(10)")
      assert String.contains?(chart, "(3)")
    end

    test "handles empty data" do
      chart = Visualization.bar_chart(%{}, title: "Empty")
      assert String.contains?(chart, "Empty")
      assert String.contains?(chart, "No data available")
    end

    test "sorts by key by default" do
      data = %{c: 1, a: 2, b: 3}
      chart = Visualization.bar_chart(data, sort: :key)

      # Lines should appear in key order
      lines = String.split(chart, "\n")
      data_lines = Enum.filter(lines, &String.contains?(&1, "│"))
      labels = Enum.map(data_lines, fn line -> line |> String.split("│") |> hd() |> String.trim() end)
      assert labels == ["a", "b", "c"]
    end

    test "sorts descending when specified" do
      data = %{a: 1, b: 5, c: 3}
      chart = Visualization.bar_chart(data, sort: :desc)

      lines = String.split(chart, "\n")
      data_lines = Enum.filter(lines, &String.contains?(&1, "│"))
      labels = Enum.map(data_lines, fn line -> line |> String.split("│") |> hd() |> String.trim() end)
      assert labels == ["b", "c", "a"]
    end

    test "sorts ascending when specified" do
      data = %{a: 5, b: 1, c: 3}
      chart = Visualization.bar_chart(data, sort: :asc)

      lines = String.split(chart, "\n")
      data_lines = Enum.filter(lines, &String.contains?(&1, "│"))
      labels = Enum.map(data_lines, fn line -> line |> String.split("│") |> hd() |> String.trim() end)
      assert labels == ["b", "c", "a"]
    end

    test "uses custom width" do
      data = %{x: 10}
      chart = Visualization.bar_chart(data, width: 10)
      assert String.contains?(chart, String.duplicate("█", 10))
    end

    test "handles single-item data" do
      chart = Visualization.bar_chart(%{only: 42}, title: "Single")
      assert String.contains?(chart, "Single")
      assert String.contains?(chart, "(42)")
    end

    test "handles numeric keys" do
      data = %{0 => 5, 1 => 10, 2 => 3}
      chart = Visualization.bar_chart(data)
      assert String.contains?(chart, "(5)")
      assert String.contains?(chart, "(10)")
    end
  end

  describe "summary_table/2" do
    test "generates a basic summary table" do
      data = %{total_sent: 100, total_received: 50}
      table = Visualization.summary_table(data, title: "Test Summary")

      assert String.contains?(table, "Test Summary")
      assert String.contains?(table, "═")
      assert String.contains?(table, "100")
      assert String.contains?(table, "50")
    end

    test "handles empty data" do
      table = Visualization.summary_table(%{}, title: "Empty")
      assert String.contains?(table, "Empty")
      assert String.contains?(table, "No data available")
    end

    test "humanizes keys" do
      data = %{total_sent: 100}
      table = Visualization.summary_table(data)
      assert String.contains?(table, "Total Sent")
    end

    test "filters out nested maps and lists" do
      data = %{count: 5, nested: %{a: 1}, items: [1, 2, 3]}
      table = Visualization.summary_table(data)
      assert String.contains?(table, "5")
      refute String.contains?(table, "nested")
      refute String.contains?(table, "items")
    end

    test "formats float values" do
      data = %{rate: 95.678}
      table = Visualization.summary_table(data)
      assert String.contains?(table, "95.68")
    end
  end

  describe "sparkline/1" do
    test "generates a sparkline from values" do
      result = Visualization.sparkline([1, 3, 5, 2, 8, 4])
      assert is_binary(result)
      assert String.length(result) > 0
      # Should contain block characters
      assert String.match?(result, ~r/[▁▂▃▄▅▆▇█]/)
    end

    test "handles empty list" do
      assert Visualization.sparkline([]) == ""
    end

    test "handles single value" do
      result = Visualization.sparkline([5])
      assert String.length(result) == 1
    end

    test "handles equal values" do
      result = Visualization.sparkline([5, 5, 5])
      # All bars should be the same
      chars = String.graphemes(result)
      assert length(Enum.uniq(chars)) == 1
    end

    test "highest value gets tallest bar" do
      result = Visualization.sparkline([1, 10, 1])
      graphemes = String.graphemes(result)
      assert Enum.at(graphemes, 1) == "█"
    end

    test "lowest value gets shortest bar" do
      result = Visualization.sparkline([5, 1, 10])
      graphemes = String.graphemes(result)
      assert Enum.at(graphemes, 1) == "▁"
    end
  end

  describe "percentage_bar/2" do
    test "generates a full bar at 100%" do
      result = Visualization.percentage_bar(100.0, width: 10)
      assert String.contains?(result, String.duplicate("█", 10))
      assert String.contains?(result, "100.0%")
    end

    test "generates an empty bar at 0%" do
      result = Visualization.percentage_bar(0.0, width: 10)
      assert String.contains?(result, String.duplicate("░", 10))
      assert String.contains?(result, "0.0%")
    end

    test "generates a half bar at 50%" do
      result = Visualization.percentage_bar(50.0, width: 10)
      assert String.contains?(result, "50.0%")
    end

    test "clamps values above 100" do
      result = Visualization.percentage_bar(150.0)
      assert String.contains?(result, "100.0%")
    end

    test "clamps values below 0" do
      result = Visualization.percentage_bar(-10.0)
      assert String.contains?(result, "0.0%")
    end
  end

  describe "full_report/1" do
    test "generates a complete report" do
      dashboard = %{
        messages: %{total_sent: 10, total_received: 5, total_forwarded: 0, total_edited: 1, total_deleted: 0, total: 16},
        commands: %{commands: %{"start" => %{count: 5, error_count: 0, success_rate: 100.0}}, total_commands: 5, most_used: "start"},
        engagement: %{total_unique_users: 3, active_users_last_hour: 2, active_users_last_day: 3},
        errors: %{total_errors: 1, errors_by_type: %{"timeout" => 1}, error_rate: 6.25, recent_errors: []},
        performance: %{avg_response_time_ms: 150.0, p50_response_time_ms: 120.0, p95_response_time_ms: 250.0, p99_response_time_ms: 300.0, min_response_time_ms: 50.0, max_response_time_ms: 400.0, throughput_per_minute: 3.2},
        usage_patterns: %{hourly_distribution: %{14 => 5, 15 => 3}, daily_distribution: %{wednesday: 8}, peak_hour: 14, peak_day: :wednesday},
        generated_at: "2025-02-25T10:00:00Z"
      }

      report = Visualization.full_report(dashboard)

      assert String.contains?(report, "📊 TELEGRAM BOT ANALYTICS REPORT")
      assert String.contains?(report, "📨 MESSAGE STATISTICS")
      assert String.contains?(report, "🤖 COMMAND STATISTICS")
      assert String.contains?(report, "👥 USER ENGAGEMENT")
      assert String.contains?(report, "❌ ERROR MONITORING")
      assert String.contains?(report, "⚡ PERFORMANCE METRICS")
      assert String.contains?(report, "📈 USAGE PATTERNS")
    end

    test "handles nil sections gracefully" do
      dashboard = %{
        messages: nil,
        commands: nil,
        engagement: nil,
        errors: nil,
        performance: nil,
        usage_patterns: nil,
        generated_at: "2025-02-25T10:00:00Z"
      }

      report = Visualization.full_report(dashboard)
      assert String.contains?(report, "No data")
    end
  end

  describe "format_duration/1" do
    test "formats milliseconds" do
      assert Visualization.format_duration(42) == "42ms"
    end

    test "formats seconds" do
      assert Visualization.format_duration(1500) == "1.5s"
    end

    test "formats minutes" do
      assert Visualization.format_duration(90_000) == "1.5m"
    end

    test "formats hours" do
      assert Visualization.format_duration(5_400_000) == "1.5h"
    end

    test "formats zero" do
      assert Visualization.format_duration(0) == "0ms"
    end

    test "formats sub-millisecond values" do
      assert Visualization.format_duration(0.5) == "1ms"
    end
  end
end
