defmodule Lux.Prisms.Telegram.Analytics.GenerateReportTest do
  use UnitCase, async: true

  alias Lux.Integrations.Telegram.Analytics
  alias Lux.Prisms.Telegram.Analytics.GenerateReport

  test "generates chart-ready reports through the prism" do
    {:ok, event} =
      Analytics.normalize_event(%{
        event_type: "command",
        command: "/help",
        occurred_at: "2026-06-15T10:00:00Z"
      })

    assert {:ok, %{report: report}} = GenerateReport.handler(%{events: [event]}, nil)
    assert [%{label: "/help", count: 1}] = report.top_commands
    assert [%{label: "/help", value: 1}] = report.chart_data.command_usage
  end
end
