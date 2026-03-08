defmodule Lux.Prisms.Telegram.AnalyticsReportTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Telegram.AnalyticsReport
  alias Lux.Integrations.Telegram.Analytics.Collector

  setup do
    name = :"report_test_#{:rand.uniform(1_000_000)}"
    {:ok, pid} = Collector.start_link(name: name)
    Collector.track_message(pid, %{from_id: 1, chat_id: -100})
    Collector.track_message(pid, %{from_id: 2, chat_id: -100, has_media: true})
    Collector.track_command(pid, "/start", 1, -100)
    Collector.track_error(pid, :timeout)
    Process.sleep(10)
    %{pid: pid}
  end

  test "full_report", %{pid: pid} do
    {:ok, report} = AnalyticsReport.handler(%{action: "full_report", collector_pid: pid}, nil)
    assert report.overview.total_messages == 2
    assert report.overview.unique_users == 2
  end

  test "errors report", %{pid: pid} do
    {:ok, %{report: report}} = AnalyticsReport.handler(%{action: "errors", collector_pid: pid}, nil)
    assert report.total == 1
    assert report.by_type[:timeout] == 1
  end

  test "engagement report", %{pid: pid} do
    {:ok, %{report: report}} = AnalyticsReport.handler(%{action: "engagement", collector_pid: pid}, nil)
    assert report.unique_users == 2
    assert report.messages_per_user == 1.0
  end

  test "patterns report", %{pid: pid} do
    {:ok, %{report: report}} = AnalyticsReport.handler(%{action: "patterns", collector_pid: pid}, nil)
    assert length(report.top_commands) >= 1
  end
end
