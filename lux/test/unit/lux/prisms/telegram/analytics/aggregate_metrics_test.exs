defmodule Lux.Prisms.Telegram.Analytics.AggregateMetricsTest do
  use UnitCase, async: true

  alias Lux.Integrations.Telegram.Analytics
  alias Lux.Prisms.Telegram.Analytics.AggregateMetrics

  test "aggregates metrics through the prism" do
    {:ok, event} =
      Analytics.normalize_event(%{
        event_type: "command",
        command: "/status",
        occurred_at: "2026-06-15T10:00:00Z"
      })

    assert {:ok, %{metrics: %{total_events: 1, command_usage: %{"/status" => 1}}}} =
             AggregateMetrics.handler(%{events: [event]}, nil)
  end
end
