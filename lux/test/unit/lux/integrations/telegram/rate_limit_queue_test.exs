defmodule Lux.Integrations.Telegram.RateLimitQueueTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.RateLimitQueue

  describe "priority queueing" do
    test "enqueues and dequeues messages by priority order" do
      q = RateLimitQueue.init_queue()
      assert RateLimitQueue.total_count(q) == 0

      # Enqueue low, normal, high
      {:ok, q1, _} = RateLimitQueue.enqueue(q, 101, %{text: "low priority"}, :low)
      {:ok, q2, _} = RateLimitQueue.enqueue(q1, 102, %{text: "normal priority"}, :normal)
      {:ok, q3, _} = RateLimitQueue.enqueue(q2, 103, %{text: "high priority alert"}, :high)

      assert RateLimitQueue.total_count(q3) == 3

      # First pop should be :high
      {:ok, q4, item1} = RateLimitQueue.dequeue(q3)
      assert item1.priority == :high
      assert item1.chat_id == 103

      # Second pop should be :normal
      {:ok, q5, item2} = RateLimitQueue.dequeue(q4)
      assert item2.priority == :normal
      assert item2.chat_id == 102

      # Third pop should be :low
      {:ok, q6, item3} = RateLimitQueue.dequeue(q5)
      assert item3.priority == :low
      assert item3.chat_id == 101

      # Queue empty
      assert {:empty, _} = RateLimitQueue.dequeue(q6)
    end
  end
end
