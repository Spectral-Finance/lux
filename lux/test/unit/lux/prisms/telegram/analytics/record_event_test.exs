defmodule Lux.Prisms.Telegram.Analytics.RecordEventTest do
  use UnitCase, async: true

  alias Lux.Prisms.Telegram.Analytics.RecordEvent

  test "records events through the prism" do
    assert {:ok, %{events: [event]}} =
             RecordEvent.handler(
               %{
                 event: %{
                   event_type: "message",
                   chat_id: 100,
                   user_id: 200,
                   occurred_at: "2026-06-15T10:00:00Z"
                 }
               },
               nil
             )

    assert event.event_type == "message"
  end
end
