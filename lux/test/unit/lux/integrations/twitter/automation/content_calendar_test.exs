defmodule Lux.Integrations.Twitter.Automation.ContentCalendarTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Twitter.Automation.ContentCalendar

  describe "ContentCalendar" do
    test "adds and retrieves recurring slots" do
      calendar = ContentCalendar.new_calendar()

      assert {:ok, calendar, slot1} =
               ContentCalendar.add_slot(calendar, 1, "09:00", :market_update)

      assert slot1.day_of_week == 1
      assert slot1.topic == :market_update
      assert length(calendar.slots) == 1

      assert {:ok, calendar, _slot2} =
               ContentCalendar.add_slot(calendar, 3, "15:00", :education)

      assert length(calendar.slots) == 2
    end

    test "removes slot by id" do
      calendar = ContentCalendar.new_calendar()
      {:ok, calendar, slot} = ContentCalendar.add_slot(calendar, 1, "09:00", :news)
      assert length(calendar.slots) == 1

      updated = ContentCalendar.remove_slot(calendar, slot.id)
      assert Enum.empty?(updated.slots)
    end

    test "plans schedule matching draft posts to upcoming slots" do
      calendar = ContentCalendar.new_calendar()
      {:ok, calendar, _} = ContentCalendar.add_slot(calendar, 1, "09:00", :education)
      {:ok, calendar, _} = ContentCalendar.add_slot(calendar, 3, "14:00", :news)

      drafts = [
        %{text: "How zk-rollups scale Ethereum", topic: :education},
        %{text: "Weekly crypto news breakdown", topic: :news}
      ]

      plan = ContentCalendar.plan_schedule(calendar, drafts)
      assert length(plan) == 2
      assert hd(plan).topic == :education
      assert hd(tl(plan)).topic == :news
    end
  end
end
