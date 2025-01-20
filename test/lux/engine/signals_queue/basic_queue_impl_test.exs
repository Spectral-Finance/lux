defmodule Lux.Engine.SignalQueue.BasicQueueImplTest do
  use Lux.Case, async: true
  alias Lux.Engine.SignalsQueue.BasicQueueImpl
  alias Lux.Signal

  describe "new/1" do
    test "creates a new queue with default options" do
      {:ok, pid} = start_supervised!(BasicQueueImpl)
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "creates a named queue" do
      name = :"test_queue_#{:erlang.unique_integer()}"
      {:ok, pid} = start_supervised!(BasicQueueImpl, name: name)
      assert Process.whereis(name) == pid
    end
  end

  describe "push/2" do
    setup %{test: test_name} do
      {:ok, queue} = start_supervised!(BasicQueueImpl, name: test_name)
      {:ok, queue: queue}
    end

    test "pushes a signal to the queue", %{queue: queue} do
      assert :ok = BasicQueueImpl.push(queue, build(:signal))
      assert BasicQueueImpl.length(queue) == 1
    end

    test "maintains order of multiple signals", %{queue: queue} do
      signals =
        for i <- 1..3 do
          signal = build(:signal, id: "test_#{i}", schema_id: "test_schema", payload: %{value: i})
          assert :ok = BasicQueueImpl.push(queue, signal)
          signal
        end

      assert BasicQueueImpl.length(queue) == 3

      for signal <- signals do
        assert {:ok, popped} = BasicQueueImpl.pop(queue)
        assert popped.id == signal.id
      end
    end
  end

  describe "pop/1" do
    setup %{test: test_name} do
      {:ok, queue} = start_supervised!(BasicQueueImpl, name: test_name)
      {:ok, queue: queue}
    end

    test "returns {:empty, nil} for empty queue", %{queue: queue} do
      assert {:empty, nil} = BasicQueueImpl.pop(queue)
    end

    test "returns and removes signal from queue", %{queue: queue} do
      signal = build(:signal)
      BasicQueueImpl.push(queue, signal)
      assert {:ok, ^signal} = BasicQueueImpl.pop(queue)
      assert {:empty, nil} = BasicQueueImpl.pop(queue)
    end
  end

  describe "length/1" do
    setup %{test: test_name} do
      {:ok, queue} = start_supervised!(BasicQueueImpl, name: test_name)
      {:ok, queue: queue}
    end

    test "returns 0 for empty queue", %{queue: queue} do
      assert BasicQueueImpl.length(queue) == 0
    end

    test "returns correct count after pushes and pops", %{queue: queue} do
      signal = build(:signal, id: "test", schema_id: "test_schema", payload: %{})

      assert BasicQueueImpl.length(queue) == 0
      BasicQueueImpl.push(queue, signal)
      assert BasicQueueImpl.length(queue) == 1
      BasicQueueImpl.push(queue, signal)
      assert BasicQueueImpl.length(queue) == 2
      BasicQueueImpl.pop(queue)
      assert BasicQueueImpl.length(queue) == 1
      BasicQueueImpl.pop(queue)
      assert BasicQueueImpl.length(queue) == 0
    end
  end

  describe "cleanup/1" do
    setup %{test: test_name} do
      {:ok, queue} = start_supervised!(BasicQueueImpl, name: test_name)
      {:ok, queue: queue}
    end

    test "empties the queue and terminates the process", %{queue: queue} do
      signal = build(:signal)
      BasicQueueImpl.push(queue, signal)
      BasicQueueImpl.push(queue, signal)
      assert BasicQueueImpl.length(queue) == 2
      ref = Process.monitor(queue)

      assert :ok = BasicQueueImpl.cleanup(queue)

      # Verify process termination
      assert_receive {:DOWN, ^ref, :process, ^queue, _}, 500
      refute Process.alive?(queue)

      # Verify subsequent calls fail
      assert catch_exit(BasicQueueImpl.length(queue))
    end
  end

  describe "to_list/1" do
    setup do
      {:ok, queue} = start_supervised!(BasicQueueImpl)
      %{queue: queue}
    end

    test "returns empty list for empty queue", %{queue: queue} do
      assert BasicQueueImpl.to_list(queue) == []
    end

    test "returns list of all signals in order", %{queue: queue} do
      signals =
        for i <- 1..3 do
          signal = %Signal{id: "test_#{i}", schema_id: "test_schema", payload: %{value: i}}
          BasicQueueImpl.push(queue, signal)
          signal
        end

      assert BasicQueueImpl.to_list(queue) == signals
    end

    test "does not modify queue", %{queue: queue} do
      signal = %Signal{id: "test", schema_id: "test_schema", payload: %{}}
      BasicQueueImpl.push(queue, signal)

      assert BasicQueueImpl.to_list(queue) == [signal]
      assert BasicQueueImpl.length(queue) == 1
      assert {:ok, ^signal} = BasicQueueImpl.pop(queue)
    end
  end
end
