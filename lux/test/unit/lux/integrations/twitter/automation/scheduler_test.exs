defmodule Lux.Integrations.Twitter.Automation.SchedulerTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Twitter.Automation.Scheduler

  describe "Scheduler" do
    test "schedules a tweet and sorts by priority and time" do
      queue = Scheduler.new_queue()
      t1 = DateTime.utc_now() |> DateTime.add(-3600, :second)
      t2 = DateTime.utc_now() |> DateTime.add(-1800, :second)

      {:ok, queue, i1} =
        Scheduler.schedule(queue, %{
          text: "Low priority announcement",
          scheduled_at: t1,
          priority: :low
        })

      {:ok, queue, i2} =
        Scheduler.schedule(queue, %{
          text: "High priority breaking news",
          scheduled_at: t2,
          priority: :high
        })

      assert i1.status == :pending
      assert i2.status == :pending

      due = Scheduler.get_due_items(queue)
      assert length(due) == 2
      # High priority item should be first even though t2 > t1
      assert hd(due).id == i2.id
    end

    test "cancels a scheduled item" do
      queue = Scheduler.new_queue()

      {:ok, queue, item} =
        Scheduler.schedule(queue, %{
          text: "Will be cancelled",
          scheduled_at: DateTime.utc_now()
        })

      assert {:ok, queue, updated} = Scheduler.cancel(queue, item.id)
      assert updated.status == :cancelled

      due = Scheduler.get_due_items(queue)
      assert Enum.empty?(due)
    end

    test "marks items as published and records tweet_id" do
      queue = Scheduler.new_queue()

      {:ok, queue, item} =
        Scheduler.schedule(queue, %{
          text: "Published tweet",
          scheduled_at: DateTime.utc_now()
        })

      assert {:ok, queue, updated} = Scheduler.mark_published(queue, item.id, "tw_123456")
      assert updated.status == :published
      assert updated.published_tweet_id == "tw_123456"
      assert updated.attempts == 1
    end

    test "tracks failed attempts up to max_attempts" do
      queue = Scheduler.new_queue()

      {:ok, queue, item} =
        Scheduler.schedule(queue, %{
          text: "Flaky network tweet",
          scheduled_at: DateTime.utc_now(),
          max_attempts: 2
        })

      {:ok, queue, u1} = Scheduler.mark_failed(queue, item.id, "Rate limited")
      assert u1.status == :pending
      assert u1.attempts == 1

      {:ok, _queue, u2} = Scheduler.mark_failed(queue, item.id, "API down")
      assert u2.status == :failed
      assert u2.attempts == 2
      assert u2.error_reason == "API down"
    end
  end
end
