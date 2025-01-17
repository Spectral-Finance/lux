defmodule Lux.Engine.Queue.DistributedQueueTest do
  use ExUnit.Case

  alias Lux.Engine.Queue.DistributedQueue

  setup do
    # Start Registry and PubSub
    start_supervised!({Registry, keys: :unique, name: Lux.Engine.Registry})
    start_supervised!({Phoenix.PubSub, name: Lux.PubSub})

    queue_name = :"test_queue_#{:erlang.unique_integer()}"
    {:ok, pid} = start_supervised({DistributedQueue, name: queue_name})

    %{queue_name: queue_name, pid: pid}
  end

  describe "start_link/1" do
    test "starts a new queue with default max size" do
      name = :"test_queue_#{:erlang.unique_integer()}"
      {:ok, pid} = DistributedQueue.start_link(name: name)
      assert Process.alive?(pid)
    end

    test "starts a new queue with custom max size" do
      name = :"test_queue_#{:erlang.unique_integer()}"
      {:ok, pid} = DistributedQueue.start_link(name: name, max_size: 5)
      assert Process.alive?(pid)
    end

    test "requires a name option" do
      assert_raise KeyError, fn ->
        DistributedQueue.start_link([])
      end
    end
  end

  describe "push/2" do
    test "adds item to queue", %{queue_name: name} do
      assert :ok = DistributedQueue.push(name, %{id: 1})
    end

    test "broadcasts push event", %{queue_name: name} do
      DistributedQueue.subscribe(name)
      item = %{id: 1}
      :ok = DistributedQueue.push(name, item)

      assert_receive {:pushed, ^item}
    end

    test "fails when queue is full", %{queue_name: name} do
      # Stop the existing supervised process
      :ok = stop_supervised(DistributedQueue)

      # Start a new process with small max size
      {:ok, _pid} = start_supervised({DistributedQueue, name: name, max_size: 2})

      assert :ok = DistributedQueue.push(name, %{id: 1})
      assert :ok = DistributedQueue.push(name, %{id: 2})
      assert {:error, :queue_full} = DistributedQueue.push(name, %{id: 3})
    end
  end

  describe "pop/1" do
    test "returns error when queue is empty", %{queue_name: name} do
      assert {:error, :empty} = DistributedQueue.pop(name)
    end

    test "removes and returns first item", %{queue_name: name} do
      item = %{id: 1}
      :ok = DistributedQueue.push(name, item)

      assert {:ok, ^item} = DistributedQueue.pop(name)
    end

    test "broadcasts pop event", %{queue_name: name} do
      DistributedQueue.subscribe(name)
      item = %{id: 1}
      :ok = DistributedQueue.push(name, item)
      {:ok, _} = DistributedQueue.pop(name)

      assert_receive {:popped, ^item}
    end

    test "maintains FIFO order", %{queue_name: name} do
      items = [%{id: 1}, %{id: 2}, %{id: 3}]
      Enum.each(items, &DistributedQueue.push(name, &1))

      assert {:ok, %{id: 1}} = DistributedQueue.pop(name)
      assert {:ok, %{id: 2}} = DistributedQueue.pop(name)
      assert {:ok, %{id: 3}} = DistributedQueue.pop(name)
    end
  end

  describe "subscribe/1 and unsubscribe/1" do
    test "subscribes to queue events", %{queue_name: name} do
      assert :ok = DistributedQueue.subscribe(name)
      item = %{id: 1}
      :ok = DistributedQueue.push(name, item)

      assert_receive {:pushed, ^item}
    end

    test "unsubscribes from queue events", %{queue_name: name} do
      :ok = DistributedQueue.subscribe(name)
      :ok = DistributedQueue.unsubscribe(name)
      :ok = DistributedQueue.push(name, %{id: 1})

      refute_receive {:pushed, _}
    end
  end
end
