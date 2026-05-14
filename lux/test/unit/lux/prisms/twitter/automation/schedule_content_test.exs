defmodule Lux.Prisms.Twitter.Automation.ScheduleContentTest do
  use UnitCase, async: true

  alias Lux.Prisms.Twitter.Automation.ScheduleContent

  test "returns scheduled content payload" do
    assert {:ok, payload} =
             ScheduleContent.handler(
               %{
                 items: [%{id: "a", text: "hello", priority: 1}],
                 start_at: "2026-05-14T09:00:00Z"
               },
               nil
             )

    assert [%{id: "a", scheduled_at: "2026-05-14T09:00:00Z"}] = payload.scheduled
    assert payload.summary.scheduled_items == 1
  end
end
