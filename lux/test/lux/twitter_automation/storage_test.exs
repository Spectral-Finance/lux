defmodule Lux.TwitterAutomation.StorageTest do
  use ExUnit.Case, async: false

  alias Lux.TwitterAutomation.Storage

  setup do
    Storage.init()
    on_exit(fn -> Storage.clear_all() end)
    :ok
  end

  describe "scheduled items storage" do
    test "stores and retrieves a scheduled item" do
      item = build_scheduled_item("item123")
      assert :ok = Storage.store_scheduled_item(item)
      assert {:ok, retrieved} = Storage.get_scheduled_item(item.id)
      assert retrieved == item
    end

    test "returns error for non-existent scheduled item" do
      assert {:error, :not_found} = Storage.get_scheduled_item("nonexistent")
    end

    test "gets scheduled items by status" do
      item1 = build_scheduled_item("item1", :pending)
      item2 = build_scheduled_item("item2", :pending)
      item3 = build_scheduled_item("item3", :completed)

      Storage.store_scheduled_item(item1)
      Storage.store_scheduled_item(item2)
      Storage.store_scheduled_item(item3)

      {:ok, pending_items} = Storage.get_scheduled_by_status(:pending)
      assert length(pending_items) == 2
      assert Enum.all?(pending_items, &(&1.status == :pending))
    end

    test "gets scheduled items in time range" do
      now = DateTime.utc_now()
      past = DateTime.add(now, -2, :hour)
      future = DateTime.add(now, 2, :hour)

      item_past = build_scheduled_item("i1", :pending, past)
      item_now = build_scheduled_item("i2", :pending, now)
      item_future = build_scheduled_item("i3", :pending, future)

      Storage.store_scheduled_item(item_past)
      Storage.store_scheduled_item(item_now)
      Storage.store_scheduled_item(item_future)

      {:ok, items} = Storage.get_scheduled_in_range(DateTime.add(now, -1, :hour), DateTime.add(now, 1, :hour))
      assert length(items) == 1
      assert hd(items).id == item_now.id
    end

    test "updates item status" do
      item = build_scheduled_item("item123", :pending)
      Storage.store_scheduled_item(item)

      assert {:ok, updated_item} = Storage.update_item_status(item.id, :completed)
      assert {:ok, retrieved} = Storage.get_scheduled_item(item.id)
      assert retrieved.status == :completed
    end

    test "deletes scheduled item" do
      item = build_scheduled_item("item123", :pending)
      Storage.store_scheduled_item(item)

      assert :ok = Storage.delete_scheduled_item(item.id)
      assert {:error, :not_found} = Storage.get_scheduled_item(item.id)
    end
  end

  describe "rules storage" do
    test "stores and retrieves a rule" do
      rule = build_rule("rule123")
      assert :ok = Storage.store_rule(rule)
      assert {:ok, retrieved} = Storage.get_rule(rule.id)
      assert retrieved == rule
    end

    test "returns error for non-existent rule" do
      assert {:error, :not_found} = Storage.get_rule("nonexistent")
    end

    test "gets all rules" do
      rule1 = build_rule("rule1")
      rule2 = build_rule("rule2", true)
      rule3 = build_rule("rule3", false)

      Storage.store_rule(rule1)
      Storage.store_rule(rule2)
      Storage.store_rule(rule3)

      {:ok, rules} = Storage.get_all_rules()
      assert length(rules) == 3
    end

    test "gets enabled rules" do
      rule1 = build_rule("rule1", true)
      rule2 = build_rule("rule2", false)
      rule3 = build_rule("rule3", true)

      Storage.store_rule(rule1)
      Storage.store_rule(rule2)
      Storage.store_rule(rule3)

      {:ok, enabled_rules} = Storage.get_enabled_rules()
      assert length(enabled_rules) == 2
      assert Enum.all?(enabled_rules, &(&1.enabled == true))
    end

    test "deletes rule" do
      rule = build_rule("rule123", true)
      Storage.store_rule(rule)

      assert :ok = Storage.delete_rule(rule.id)
      assert {:error, :not_found} = Storage.get_rule(rule.id)
    end
  end

  describe "queue storage" do
    test "enqueues and dequeues an action" do
      action = build_action("action123")
      assert :ok = Storage.enqueue_action(action)

      assert {:ok, dequeued_action} = Storage.dequeue_action()
      assert dequeued_action.id == action.id
    end

    test "dequeues actions by priority order" do
      high_priority_action = build_action("high_action", :high)
      low_priority_action = build_action("low_action", :low)
      normal_priority_action = build_action("normal_action", :normal)

      Storage.enqueue_action(low_priority_action)
      Storage.enqueue_action(high_priority_action)
      Storage.enqueue_action(normal_priority_action)

      assert {:ok, dequeued_high} = Storage.dequeue_action()
      assert dequeued_high.id == high_priority_action.id
      assert {:ok, dequeued_normal} = Storage.dequeue_action()
      assert dequeued_normal.id == normal_priority_action.id
      assert {:ok, dequeued_low} = Storage.dequeue_action()
      assert dequeued_low.id == low_priority_action.id
    end

    test "returns nil when queue is empty" do
      assert {:ok, nil} = Storage.dequeue_action()
    end

    test "gets queue size" do
      action1 = build_action("action1")
      action2 = build_action("action2")

      assert 0 == Storage.get_queue_size()
      Storage.enqueue_action(action1)
      assert 1 == Storage.get_queue_size()
      Storage.enqueue_action(action2)
      assert 2 == Storage.get_queue_size()
    end

    test "gets queue stats" do
      action1 = build_action("action1", :high)
      action2 = build_action("action2", :normal)
      action3 = build_action("action3", :high)

      Storage.enqueue_action(action1)
      Storage.enqueue_action(action2)
      Storage.enqueue_action(action3)

      {:ok, stats} = Storage.get_queue_stats()
      assert stats.total == 3
      assert stats.by_priority[:high] == 2
      assert stats.by_priority[:normal] == 1
    end
  end

  describe "calendar storage" do
    test "stores and retrieves a calendar item" do
      item = build_calendar_item("cal123")
      assert :ok = Storage.store_calendar_item(item)
      assert {:ok, retrieved} = Storage.get_calendar_item(item.id)
      assert retrieved == item
    end

    test "returns error for non-existent calendar item" do
      assert {:error, :not_found} = Storage.get_calendar_item("nonexistent")
    end

    test "gets content by status" do
      item1 = build_calendar_item("cal1", :draft)
      item2 = build_calendar_item("cal2", :draft)
      item3 = build_calendar_item("cal3", :published)

      Storage.store_calendar_item(item1)
      Storage.store_calendar_item(item2)
      Storage.store_calendar_item(item3)

      {:ok, draft_items} = Storage.get_content_by_status(:draft)
      assert length(draft_items) == 2
      assert Enum.all?(draft_items, &(&1.status == :draft))
    end

    test "gets content by tag" do
      item1 = build_calendar_item("cal1", :draft, ["elixir", "programming"])
      item2 = build_calendar_item("cal2", :draft, ["phoenix", "elixir"])
      item3 = build_calendar_item("cal3", :published, ["marketing"])

      Storage.store_calendar_item(item1)
      Storage.store_calendar_item(item2)
      Storage.store_calendar_item(item3)

      items_with_elixir = Storage.get_content_by_tag("elixir")
      assert length(items_with_elixir) == 2
      assert Enum.all?(items_with_elixir, &(Enum.member?(&1.tags, "elixir")))
    end

    test "gets calendar in date range" do
      now = DateTime.utc_now()
      past = DateTime.add(now, -2, :day)
      future = DateTime.add(now, 2, :day)

      item_past = build_calendar_item("cal1", :draft, ["tag"], past)
      item_now = build_calendar_item("cal2", :draft, ["tag"], now)
      item_future = build_calendar_item("cal3", :draft, ["tag"], future)

      Storage.store_calendar_item(item_past)
      Storage.store_calendar_item(item_now)
      Storage.store_calendar_item(item_future)

      {:ok, items} = Storage.get_calendar_range(DateTime.add(now, -1, :day), DateTime.add(now, 1, :day))
      assert length(items) == 1
      assert hd(items).id == item_now.id
    end

    test "deletes calendar item" do
      item = build_calendar_item("cal123")
      Storage.store_calendar_item(item)

      assert :ok = Storage.delete_calendar_item(item.id)
      assert {:error, :not_found} = Storage.get_calendar_item(item.id)
    end
  end

  describe "stats" do
    test "returns storage statistics" do
      Storage.store_scheduled_item(build_scheduled_item("s1"))
      Storage.store_scheduled_item(build_scheduled_item("s2"))
      Storage.store_rule(build_rule("r1"))
      Storage.store_calendar_item(build_calendar_item("c1"))

      action1 = build_action("a1")
      action2 = build_action("a2")
      Storage.enqueue_action(action1)
      Storage.enqueue_action(action2)

      stats = Storage.get_stats()
      assert stats.scheduled_count == 2
      assert stats.rules_count == 1
      assert stats.queue_size == 2
      assert stats.calendar_count == 1
    end
  end

  describe "clear_all" do
    test "clears all data" do
      Storage.store_scheduled_item(build_scheduled_item("s1"))
      Storage.store_rule(build_rule("r1"))
      Storage.store_calendar_item(build_calendar_item("c1"))
      Storage.enqueue_action(build_action("a1"))

      assert :ok = Storage.clear_all()

      stats = Storage.get_stats()
      assert stats.scheduled_count == 0
      assert stats.rules_count == 0
      assert stats.queue_size == 0
      assert stats.calendar_count == 0
    end
  end

  ## Helpers

  defp build_scheduled_item(id, status \\ :pending, scheduled_time \\ nil) do
    %{
      id: id,
      status: status,
      scheduled_time: scheduled_time || DateTime.utc_now(),
      action_type: :tweet,
      action_data: %{},
      created_at: DateTime.utc_now(),
      metadata: %{}
    }
  end

  defp build_rule(id, enabled \\ true) do
    %{
      id: id,
      enabled: enabled,
      description: "Test rule",
      condition: %{},
      action: %{},
      created_at: DateTime.utc_now()
    }
  end

  defp build_action(id, priority \\ :normal) do
    %{
      id: id,
      priority: priority,
      action_type: :tweet,
      action_data: %{},
      created_at: DateTime.utc_now()
    }
  end

  defp build_calendar_item(id, status \\ :draft, tags \\ [], publish_date \\ nil) do
    %{
      id: id,
      status: status,
      title: "Test Content",
      content: "Test content for calendar item",
      tags: tags,
      publish_date: publish_date || DateTime.utc_now(),
      created_at: DateTime.utc_now(),
      metadata: %{}
    }
  end
end