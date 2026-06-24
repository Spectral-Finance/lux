defmodule Lux.Integrations.Twitter.QueueTest do
  use ExUnit.Case
  alias Lux.Integrations.Twitter.Queue

  setup do
    start_supervised!(Queue)
    :ok
  end

  test "enqueues and lists items" do
    Queue.enqueue("test tweet", DateTime.utc_now())
    assert length(Queue.list_all()) == 1
  end

  test "dequeues only due items" do
    past = DateTime.add(DateTime.utc_now(), -3600, :second)
    future = DateTime.add(DateTime.utc_now(), 3600, :second)

    Queue.enqueue("due tweet", past)
    Queue.enqueue("future tweet", future)

    due = Queue.dequeue_due()
    assert length(due) == 1
    assert hd(due).text == "due tweet"

    remaining = Queue.list_all()
    assert length(remaining) == 1
    assert hd(remaining).text == "future tweet"
  end

  test "clears queue" do
    Queue.enqueue("tweet", DateTime.utc_now())
    Queue.clear()
    assert Queue.list_all() == []
  end
end
