defmodule Lux.Prisms.Telegram.AnalyticsPrismsTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Telegram.Analytics.{
    CollectMetric,
    AggregateMetrics,
    TrackPerformance,
    AnalyzeUsagePatterns,
    GenerateReport
  }

  describe "Telegram Analytics Prisms" do
    test "CollectMetric prism captures interaction event" do
      params = %{
        type: "command",
        command: "trade",
        chat_id: -1001,
        user_id: 42,
        latency_ms: 150,
        status: "success"
      }

      assert {:ok, result} = CollectMetric.handler(params, %{})
      assert String.starts_with?(result.id, "evt_")
      assert result.type == "command"
      assert result.status == "success"
    end

    test "AggregateMetrics prism computes overview metrics" do
      t = DateTime.utc_now()
      events = [
        %{type: :message, chat_type: "supergroup", timestamp: t, metadata: %{message_type: :text}, user_id: 1, chat_id: -100},
        %{type: :command, command: "help", status: :success, latency_ms: 50, chat_type: "private", timestamp: t, user_id: 1, chat_id: 1}
      ]

      assert {:ok, result} = AggregateMetrics.handler(%{events: events}, %{})
      assert result.messages.total_messages == 2
      assert result.engagement.unique_active_users == 1
      assert result.commands.total_command_invocations == 1
    end

    test "TrackPerformance prism computes latencies and error rates" do
      events = [
        %{status: :success, latency_ms: 100, error_code: nil},
        %{status: :error, latency_ms: 300, error_code: 500}
      ]

      assert {:ok, result} = TrackPerformance.handler(%{events: events}, %{})
      assert result.error_rate_percent == 50.0
      assert result.latency.avg_ms == 200.0
    end

    test "AnalyzeUsagePatterns prism extracts temporal patterns" do
      events = [
        %{timestamp: DateTime.utc_now()}
      ]

      assert {:ok, result} = AnalyzeUsagePatterns.handler(%{events: events}, %{})
      assert is_integer(result.peak_hour_utc)
      assert is_binary(result.busiest_day)
    end

    test "GenerateReport prism renders markdown and html reports" do
      analytics = %{
        messages: %{total_messages: 100},
        engagement: %{unique_active_users: 25},
        commands: %{total_command_invocations: 40, commands: []},
        performance: %{error_rate_percent: 1.0, latency: %{p95: 150}, rate_limit_429_count: 0}
      }

      assert {:ok, md} = GenerateReport.handler(%{analytics: analytics, format: "markdown"}, %{})
      assert String.contains?(md.report, "Telegram Bot Analytics")

      assert {:ok, html} = GenerateReport.handler(%{analytics: analytics, format: "html"}, %{})
      assert String.contains?(html.report, "<b>Telegram Bot Analytics Report</b>")
    end
  end
end
