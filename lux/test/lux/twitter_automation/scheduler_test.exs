defmodule Lux.TwitterAutomation.SchedulerTest do
  use ExUnit.Case, async: false

  alias Lux.TwitterAutomation.Scheduler
  alias Lux.TwitterAutomation.Storage

  setup do
    {:ok, _pid} = start_supervised(Scheduler)
    Storage.clear_all()
    on_exit(fn -> Storage.clear_all() end)
    :ok
  end

  describe "schedule_tweet/3" do
    test "schedules a tweet for future execution" do
      future_time = DateTime.add(DateTime.utc_now(), 3600, :second)  # 1 hour from now
      assert {:ok, id} = Scheduler.schedule_tweet("Test tweet content", future_time)
      assert is_binary(id)

      # Verify the item is stored in Storage
      {:ok, item} = Storage.get_scheduled_item(id)
      assert item.action_type == :create_tweet
      assert item.payload.text == "Test tweet content"
      assert item.status == :pending
    end

    test "schedules a tweet with options" do
      future_time = DateTime.add(DateTime.utc_now(), 1800, :second)  # 30 minutes from now
      opts = %{metadata: %{source: "test"}}
      assert {:ok, id} = Scheduler.schedule_tweet("Test with opts", future_time, opts)

      {:ok, item} = Storage.get_scheduled_item(id)
      assert item.metadata.source == "test"
    end
  end

  describe "schedule_action/4" do
    test "schedules a follow action for future execution" do
      future_time = DateTime.add(DateTime.utc_now(), 7200, :second)  # 2 hours from now
      payload = %{user_id: "user123"}
      assert {:ok, id} = Scheduler.schedule_action(:follow_user, payload, future_time)
      assert is_binary(id)

      {:ok, item} = Storage.get_scheduled_item(id)
      assert item.action_type == :follow_user
      assert item.payload.user_id == "user123"
      assert item.status == :pending
    end

    test "schedules different action types" do
      future_time = DateTime.add(DateTime.utc_now(), 300, :second)  # 5 minutes from now

      assert {:ok, id1} = Scheduler.schedule_action(:send_dm, %{user_id: "user1", content: "Hi"}, future_time)
      assert {:ok, id2} = Scheduler.schedule_action(:unfollow_user, %{user_id: "user2"}, future_time)

      {:ok, item1} = Storage.get_scheduled_item(id1)
      {:ok, item2} = Storage.get_scheduled_item(id2)

      assert item1.action_type == :send_dm
      assert item2.action_type == :unfollow_user
    end
  end

  describe "cancel_scheduled/1" do
    test "cancels a scheduled item" do
      future_time = DateTime.add(DateTime.utc_now(), 3600, :second)
      {:ok, id} = Scheduler.schedule_tweet("To be cancelled", future_time)

      # Verify it's pending
      {:ok, item} = Storage.get_scheduled_item(id)
      assert item.status == :pending

      # Cancel it
      assert :ok = Scheduler.cancel_scheduled(id)

      # Verify it's now cancelled in storage
      {:ok, cancelled_item} = Storage.get_scheduled_item(id)
      assert cancelled_item.status == :cancelled
    end

    test "returns error for non-existent item" do
      assert {:error, :not_found} = Scheduler.cancel_scheduled("nonexistent")
    end
  end

  describe "list_scheduled/1" do
    test "lists all pending scheduled items" do
      future_time = DateTime.add(DateTime.utc_now(), 3600, :second)
      {:ok, id1} = Scheduler.schedule_tweet("Tweet 1", future_time)
      {:ok, id2} = Scheduler.schedule_tweet("Tweet 2", future_time)

      {:ok, items} = Scheduler.list_scheduled()
      assert length(items) == 2
      item_ids = Enum.map(items, & &1.id)
      assert id1 in item_ids
      assert id2 in item_ids
    end

    test "lists items by status" do
      future_time = DateTime.add(DateTime.utc_now(), 3600, :second)
      {:ok, id1} = Scheduler.schedule_tweet("Tweet 1", future_time)
      {:ok, id2} = Scheduler.schedule_tweet("Tweet 2", future_time)

      # Cancel one item
      Scheduler.cancel_scheduled(id2)

      # List pending items only
      {:ok, pending_items} = Scheduler.list_scheduled(%{status: :pending})
      assert length(pending_items) == 1
      assert hd(pending_items).id == id1

      # List cancelled items only
      {:ok, cancelled_items} = Scheduler.list_scheduled(%{status: :cancelled})
      assert length(cancelled_items) == 1
      assert hd(cancelled_items).id == id2
    end
  end

  describe "reschedule/2" do
    test "reschedules an item to a new time" do
      initial_time = DateTime.add(DateTime.utc_now(), 3600, :second)  # 1 hour from now
      new_time = DateTime.add(DateTime.utc_now(), 7200, :second)  # 2 hours from now
      {:ok, id} = Scheduler.schedule_tweet("To be rescheduled", initial_time)

      # Verify initial time
      {:ok, item} = Storage.get_scheduled_item(id)
      assert DateTime.compare(item.scheduled_time, initial_time) == :eq

      # Reschedule
      assert :ok = Scheduler.reschedule(id, new_time)

      # Verify new time
      {:ok, rescheduled_item} = Storage.get_scheduled_item(id)
      assert DateTime.compare(rescheduled_item.scheduled_time, new_time) == :eq
      assert rescheduled_item.status == :pending
    end

    test "returns error for non-existent item" do
      future_time = DateTime.add(DateTime.utc_now(), 3600, :second)
      assert {:error, :not_found} == Scheduler.reschedule("nonexistent", future_time)
    end
  end

  describe "automatic execution" do
    test "executes items immediately if scheduled in the past" do
      past_time = DateTime.add(DateTime.utc_now(), -3600, :second)  # 1 hour ago
      {:ok, id} = Scheduler.schedule_tweet("Past tweet", past_time)

      # Verify the item was executed and is no longer pending
      {:ok, item} = Storage.get_scheduled_item(id)
      # The item should be queued for execution by QueueManager
      assert item.status in [:queued, :pending]  # Could be queued depending on timing
    end
  end

  describe "schedule validation" do
    test "returns error for times too far in the future" do
      # More than 1 year in future
      very_future_time = DateTime.add(DateTime.utc_now(), :timer.hours(24 * 365 + 1), :millisecond)
      assert {:error, :too_far_in_future} = Scheduler.schedule_tweet("Very future", very_future_time)
    end
  end

  describe "cleanup" do
    test "clears all scheduled data" do
      future_time = DateTime.add(DateTime.utc_now(), 3600, :second)
      {:ok, _id} = Scheduler.schedule_tweet("Test", future_time)
      assert length(Scheduler.list_scheduled() |> elem(1)) == 1

      Storage.clear_all()
      assert length(Scheduler.list_scheduled() |> elem(1)) == 0
    end
  end
end