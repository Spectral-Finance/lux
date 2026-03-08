defmodule Lux.Prisms.Discord.EventHandlingTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.Discord.EventHandling

  setup do
    name = :"event_#{:rand.uniform(1_000_000)}"
    {:ok, pid} = EventHandling.start_link(name: name)
    %{pid: pid}
  end

  test "create event", %{pid: pid} do
    {:ok, event} = EventHandling.create_event(pid, %{
      name: "Game Night",
      start_time: DateTime.utc_now() |> DateTime.add(86400),
      channel_id: "ch1"
    })
    assert event.name == "Game Night"
    assert event.status == :scheduled
  end

  test "cancel event", %{pid: pid} do
    {:ok, event} = EventHandling.create_event(pid, %{name: "Cancel me", start_time: DateTime.utc_now()})
    :ok = EventHandling.cancel_event(pid, event.id)
    {:ok, found} = EventHandling.get_event(pid, event.id)
    assert found.status == :cancelled
  end

  test "list events", %{pid: pid} do
    {:ok, _} = EventHandling.create_event(pid, %{name: "E1", start_time: DateTime.utc_now() |> DateTime.add(3600)})
    {:ok, _} = EventHandling.create_event(pid, %{name: "E2", start_time: DateTime.utc_now() |> DateTime.add(7200)})
    {:ok, events} = EventHandling.list_events(pid)
    assert length(events) == 2
  end

  test "list by status", %{pid: pid} do
    {:ok, e} = EventHandling.create_event(pid, %{name: "E1", start_time: DateTime.utc_now()})
    {:ok, _} = EventHandling.create_event(pid, %{name: "E2", start_time: DateTime.utc_now()})
    EventHandling.cancel_event(pid, e.id)
    {:ok, scheduled} = EventHandling.list_events(pid, %{status: :scheduled})
    assert length(scheduled) == 1
  end

  test "add reminder", %{pid: pid} do
    future = DateTime.utc_now() |> DateTime.add(7200)
    {:ok, event} = EventHandling.create_event(pid, %{name: "E1", start_time: future})
    {:ok, reminder} = EventHandling.add_reminder(pid, event.id, 30)
    assert reminder.event_id == event.id
  end

  test "get due reminders", %{pid: pid} do
    past = DateTime.utc_now() |> DateTime.add(60)
    {:ok, event} = EventHandling.create_event(pid, %{name: "Soon", start_time: past})
    {:ok, _} = EventHandling.add_reminder(pid, event.id, 5)  # remind 5 min before (already due)
    {:ok, due} = EventHandling.get_due_reminders(pid)
    assert length(due) >= 1
  end

  test "rsvp", %{pid: pid} do
    {:ok, event} = EventHandling.create_event(pid, %{name: "Party", start_time: DateTime.utc_now()})
    {:ok, rsvp} = EventHandling.rsvp(pid, event.id, "user1", :going)
    assert rsvp.status == :going
    {:ok, found} = EventHandling.get_event(pid, event.id)
    assert found.rsvps["user1"] == :going
  end

  test "not found event", %{pid: pid} do
    assert {:error, :not_found} = EventHandling.get_event(pid, "nope")
    assert {:error, :not_found} = EventHandling.cancel_event(pid, "nope")
  end
end
