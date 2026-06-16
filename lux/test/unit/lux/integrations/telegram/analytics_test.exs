defmodule Lux.Integrations.Telegram.AnalyticsTest do
  use UnitCase, async: true

  alias Lux.Integrations.Telegram.Analytics

  @event %{
    event_type: "command",
    chat_id: 100,
    user_id: 200,
    command: "/start",
    duration_ms: 42,
    error: nil,
    ok: true,
    occurred_at: "2026-06-15T10:00:00Z"
  }

  test "normalizes analytics events" do
    assert {:ok, event} = Analytics.normalize_event(@event)
    assert event.event_type == "command"
    assert event.command == "/start"
    assert event.occurred_at == ~U[2026-06-15 10:00:00Z]
  end

  test "records normalized events" do
    assert {:ok, [event]} = Analytics.record_event([], @event)
    assert event.user_id == 200
  end

  test "aggregates usage, command, error, and performance metrics" do
    events = [
      normalize!(%{@event | command: "/start", duration_ms: 50, ok: true}),
      normalize!(%{@event | command: "/status", duration_ms: 150, ok: true, user_id: 201}),
      normalize!(%{@event | command: "/status", duration_ms: 250, ok: false, error: "timeout"})
    ]

    metrics = Analytics.aggregate(events)

    assert metrics.total_events == 3
    assert metrics.command_events == 3
    assert metrics.unique_users == 2
    assert metrics.command_usage == %{"/start" => 1, "/status" => 2}
    assert metrics.errors == 1
    assert metrics.error_rate == 1 / 3
    assert metrics.average_duration_ms == 150.0
  end

  test "generates report with chart-ready data and recommendations" do
    events = [
      normalize!(%{@event | ok: false, error: "timeout"}),
      normalize!(%{@event | ok: true})
    ]

    report = Analytics.report(events)

    assert [%{label: "/start", count: 2}] = report.top_commands
    assert [%{label: "2026-06-15", value: 2}] = report.chart_data.daily_usage
    assert "Investigate Telegram bot errors; error rate is above 5%." in report.recommendations
  end

  defp normalize!(event) do
    {:ok, normalized} = Analytics.normalize_event(event)
    normalized
  end
end
