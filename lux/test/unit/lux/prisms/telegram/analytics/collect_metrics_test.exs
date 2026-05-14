defmodule Lux.Prisms.Telegram.Analytics.CollectMetricsTest do
  use UnitCase, async: true

  alias Lux.Prisms.Telegram.Analytics.CollectMetrics

  test "returns a full analytics report from updates" do
    assert {:ok, report} =
             CollectMetrics.handler(
               %{
                 updates: [
                   %{message: %{text: "/help", chat: %{id: 1}, from: %{id: 2}}},
                   %{ok: false, error: "rate_limited"}
                 ],
                 previous_user_ids: [2]
               },
               %{name: "Agent"}
             )

    assert report.totals.total_updates == 2
    assert report.commands.top_commands == [%{value: "help", count: 1}]
    assert report.errors.error_rate == 0.5
    assert report.retention.retained_users == 1
  end
end
