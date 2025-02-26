defmodule Lux.Memory.SimpleMemoryTest do
  use UnitCase, async: true

  alias Lux.Memory.SimpleMemory

  describe "initialization" do
    test "initializes with default name" do
      assert {:ok, pid} = SimpleMemory.initialize([])
      assert is_pid(pid)
    end

    test "initializes with custom name" do
      name = :test_memory
      assert {:ok, pid} = SimpleMemory.initialize(name: name)
      assert Process.whereis(name) == pid
    end
  end

  describe "memory operations" do
    setup do
      {:ok, pid} = SimpleMemory.initialize([])
      %{pid: pid}
    end

    test "adds entry with defaults", %{pid: pid} do
      assert {:ok, entry} = SimpleMemory.add(pid, "test content")
      assert entry.content == "test content"
      assert entry.type == :observation
      assert entry.metadata == %{}
      assert is_integer(entry.timestamp)
      assert entry.id == 0
    end

    test "adds entry with custom type and metadata", %{pid: pid} do
      metadata = %{source: "test"}
      assert {:ok, entry} = SimpleMemory.add(pid, "test content", :interaction, metadata)
      assert entry.content == "test content"
      assert entry.type == :interaction
      assert entry.metadata == metadata
      assert is_integer(entry.timestamp)
    end

    test "maintains chronological order", %{pid: pid} do
      # Add entries with different timestamps
      timestamps =
        for i <- 1..3 do
          ts = System.system_time(:second) + i
          {:ok, entry} = SimpleMemory.add(pid, "content #{i}", :observation, %{timestamp: ts})
          entry.timestamp
        end

      assert timestamps == Enum.sort(timestamps)

      # Verify retrieval order
      {:ok, recent} = SimpleMemory.recent(pid, 3)
      retrieved_timestamps = Enum.map(recent, & &1.timestamp)
      assert retrieved_timestamps == Enum.reverse(timestamps)
    end

    test "generates sequential IDs", %{pid: pid} do
      entries =
        for i <- 1..3 do
          {:ok, entry} = SimpleMemory.add(pid, "content #{i}")
          entry
        end

      ids = Enum.map(entries, & &1.id)
      assert ids == [0, 1, 2]
    end

    test "retrieves recent entries in reverse chronological order", %{pid: pid} do
      _entries =
        for i <- 1..5 do
          {:ok, entry} = SimpleMemory.add(pid, "content #{i}")
          entry
        end

      assert {:ok, recent} = SimpleMemory.recent(pid, 3)
      assert length(recent) == 3
      assert Enum.map(recent, & &1.content) == ["content 5", "content 4", "content 3"]
    end

    test "retrieves entries by time window", %{pid: pid} do
      start_time = DateTime.utc_now()

      # Add entries with specific timestamps
      {:ok, _} =
        SimpleMemory.add(pid, "before window", :observation, %{
          timestamp: DateTime.to_unix(DateTime.add(start_time, -3600))
        })

      {:ok, _} =
        SimpleMemory.add(pid, "in window 1", :observation, %{
          timestamp: DateTime.to_unix(DateTime.add(start_time, 1))
        })

      {:ok, _} =
        SimpleMemory.add(pid, "in window 2", :observation, %{
          timestamp: DateTime.to_unix(DateTime.add(start_time, 1800))
        })

      {:ok, _} =
        SimpleMemory.add(pid, "after window", :observation, %{
          timestamp: DateTime.to_unix(DateTime.add(start_time, 7200))
        })

      end_time = DateTime.add(start_time, 3600)

      assert {:ok, entries} = SimpleMemory.window(pid, start_time, end_time)
      assert length(entries) == 2
      assert entries |> Enum.map(& &1.content) |> Enum.sort() == ["in window 1", "in window 2"]
    end

    test "searches entries case-insensitively", %{pid: pid} do
      {:ok, _} = SimpleMemory.add(pid, "Test Content One")
      {:ok, _} = SimpleMemory.add(pid, "test content two")
      {:ok, _} = SimpleMemory.add(pid, "Different message")

      assert {:ok, entries} = SimpleMemory.search(pid, "test content")
      assert length(entries) == 2
      contents = entries |> Enum.map(& &1.content) |> Enum.sort()
      assert contents == ["Test Content One", "test content two"]
    end
  end
end
