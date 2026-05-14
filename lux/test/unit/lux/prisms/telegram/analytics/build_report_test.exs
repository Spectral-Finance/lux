defmodule Lux.Prisms.Telegram.Analytics.BuildReportTest do
  use UnitCase, async: true

  alias Lux.Prisms.Telegram.Analytics.BuildReport

  test "formats a compact report payload" do
    assert {:ok, payload} =
             BuildReport.handler(
               %{
                 title: "Daily Telegram Ops",
                 updates: [
                   %{message: %{text: "hello", chat: %{id: 1}, from: %{id: 2}}, latency_ms: 80}
                 ]
               },
               nil
             )

    assert payload.title == "Daily Telegram Ops"
    assert payload.summary.total_updates == 1
    assert payload.summary.active_chats == 1
    assert length(payload.sections) == 6
    assert Map.has_key?(payload.visualizations, :event_type_bar)
  end
end
