defmodule Lux.Prisms.Twitter.Automation.ManageQueueTest do
  use UnitCase, async: true

  alias Lux.Prisms.Twitter.Automation.ManageQueue

  test "returns rate-limited queue payload" do
    assert {:ok, payload} =
             ManageQueue.handler(
               %{
                 actions: [
                   %{action: :reply, target_id: "1", text: "one"},
                   %{action: :like, target_id: "2"}
                 ],
                 now: "2026-05-14T10:00:00Z",
                 per_window_limit: 1,
                 window_minutes: 10
               },
               nil
             )

    assert length(payload.queued) == 2

    assert Enum.map(payload.queued, & &1.run_at) == [
             "2026-05-14T10:00:00Z",
             "2026-05-14T10:10:00Z"
           ]
  end
end
