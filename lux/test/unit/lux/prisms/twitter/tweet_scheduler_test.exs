defmodule Lux.Prisms.Twitter.TweetSchedulerTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Twitter.TweetScheduler

  setup do
    name = :"sched_#{:rand.uniform(1_000_000)}"
    {:ok, pid} = TweetScheduler.start_link(name: name)
    %{pid: pid}
  end

  test "schedule and list tweets", %{pid: pid} do
    future = DateTime.utc_now() |> DateTime.add(3600)
    {:ok, entry} = TweetScheduler.schedule(pid, %{text: "Hello world!", scheduled_at: future})
    assert entry.text == "Hello world!"
    assert entry.status == :scheduled

    {:ok, list} = TweetScheduler.list_scheduled(pid)
    assert length(list) == 1
  end

  test "cancel scheduled tweet", %{pid: pid} do
    future = DateTime.utc_now() |> DateTime.add(3600)
    {:ok, entry} = TweetScheduler.schedule(pid, %{text: "To cancel", scheduled_at: future})
    :ok = TweetScheduler.cancel(pid, entry.id)
    {:ok, list} = TweetScheduler.list_scheduled(pid)
    assert list == []
  end

  test "cancel non-existent returns error", %{pid: pid} do
    assert {:error, :not_found} = TweetScheduler.cancel(pid, "nonexistent")
  end

  test "get due tweets", %{pid: pid} do
    past = DateTime.utc_now() |> DateTime.add(-60)
    future = DateTime.utc_now() |> DateTime.add(3600)
    {:ok, _} = TweetScheduler.schedule(pid, %{text: "Due", scheduled_at: past})
    {:ok, _} = TweetScheduler.schedule(pid, %{text: "Not due", scheduled_at: future})

    {:ok, due} = TweetScheduler.get_due(pid)
    assert length(due) == 1
    assert hd(due).text == "Due"
  end

  test "mark posted", %{pid: pid} do
    {:ok, entry} = TweetScheduler.schedule(pid, %{text: "Post me", scheduled_at: DateTime.utc_now()})
    :ok = TweetScheduler.mark_posted(pid, entry.id, %{tweet_id: "123"})
    {:ok, s} = TweetScheduler.stats(pid)
    assert s.posted == 1
  end

  test "calendar view", %{pid: pid} do
    today = Date.utc_today()
    tomorrow = Date.add(today, 1)
    {:ok, _} = TweetScheduler.schedule(pid, %{text: "Today", scheduled_at: DateTime.new!(today, ~T[12:00:00])})
    {:ok, _} = TweetScheduler.schedule(pid, %{text: "Tomorrow", scheduled_at: DateTime.new!(tomorrow, ~T[12:00:00])})

    {:ok, cal} = TweetScheduler.calendar(pid, {today, tomorrow})
    assert Map.has_key?(cal, today)
    assert Map.has_key?(cal, tomorrow)
  end

  test "queue ordering by scheduled_at", %{pid: pid} do
    t1 = DateTime.utc_now() |> DateTime.add(7200)
    t2 = DateTime.utc_now() |> DateTime.add(3600)
    {:ok, _} = TweetScheduler.schedule(pid, %{text: "Later", scheduled_at: t1})
    {:ok, _} = TweetScheduler.schedule(pid, %{text: "Sooner", scheduled_at: t2})

    {:ok, list} = TweetScheduler.list_scheduled(pid)
    assert hd(list).text == "Sooner"
  end

  test "thread scheduling", %{pid: pid} do
    future = DateTime.utc_now() |> DateTime.add(3600)
    {:ok, entry} = TweetScheduler.schedule(pid, %{
      text: "Thread 1/3",
      scheduled_at: future,
      thread: ["Thread 2/3", "Thread 3/3"]
    })
    assert entry.thread == ["Thread 2/3", "Thread 3/3"]
  end
end
