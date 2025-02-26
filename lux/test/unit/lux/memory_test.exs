defmodule Lux.Test.MockMemory do
  @moduledoc false
  @behaviour Lux.Memory

  @registry_table :lux_memory_registry

  @impl true
  def initialize(opts) do
    # Ensure registry exists
    @registry_table
    |> :ets.whereis()
    |> case do
      :undefined -> :ets.new(@registry_table, [:set, :public, :named_table])
      _table_id -> :ok
    end

    memory_ref = opts[:name] || make_ref()
    # Register ourselves in the registry
    true = :ets.insert(@registry_table, {memory_ref, {nil, nil, __MODULE__}})
    {:ok, memory_ref}
  end

  @impl true
  def add(memory_ref, content, type \\ :observation, metadata \\ %{}) do
    entry = %{
      content: content,
      type: type,
      timestamp: System.system_time(:second),
      metadata: metadata
    }

    send(self(), {:memory_add, memory_ref, entry})
    {:ok, entry}
  end

  @impl true
  def recent(memory_ref, n) do
    send(self(), {:memory_recent, memory_ref, n})
    {:ok, []}
  end

  @impl true
  def window(memory_ref, start_time, end_time) do
    send(self(), {:memory_window, memory_ref, start_time, end_time})
    {:ok, []}
  end

  @impl true
  def search(memory_ref, query) do
    send(self(), {:memory_search, memory_ref, query})
    {:ok, []}
  end
end

defmodule Lux.MemoryTest do
  use UnitCase, async: true

  alias Lux.Test.MockMemory

  describe "named memory" do
    defmodule TestMemory do
      @moduledoc false
      use Lux.Memory,
        backend: MockMemory,
        name: :test_memory
    end

    test "initializes with name" do
      assert {:ok, :test_memory} = TestMemory.initialize()
    end

    test "adds entry with defaults" do
      TestMemory.initialize()
      assert {:ok, _entry} = TestMemory.add("test content")

      assert_received {:memory_add, :test_memory,
                       %{
                         content: "test content",
                         type: :observation,
                         metadata: %{},
                         timestamp: timestamp
                       }}
                      when is_integer(timestamp)
    end

    test "adds entry with custom type and metadata" do
      TestMemory.initialize()
      metadata = %{source: "test"}
      assert {:ok, _entry} = TestMemory.add("test content", :interaction, metadata)

      assert_received {:memory_add, :test_memory,
                       %{
                         content: "test content",
                         type: :interaction,
                         metadata: ^metadata,
                         timestamp: timestamp
                       }}
                      when is_integer(timestamp)
    end

    test "retrieves recent entries" do
      TestMemory.initialize()
      assert {:ok, []} = TestMemory.recent(5)
      assert_received {:memory_recent, :test_memory, 5}
    end

    test "retrieves entries by time window" do
      TestMemory.initialize()
      start_time = DateTime.utc_now()
      end_time = DateTime.add(start_time, 3600)
      assert {:ok, []} = TestMemory.window(start_time, end_time)
      assert_received {:memory_window, :test_memory, ^start_time, ^end_time}
    end

    test "searches entries" do
      TestMemory.initialize()
      assert {:ok, []} = TestMemory.search("test")
      assert_received {:memory_search, :test_memory, "test"}
    end
  end

  describe "dynamic memory" do
    test "initializes with backend" do
      assert {:ok, _ref} = Lux.Memory.initialize(backend: MockMemory)
    end

    test "adds entry with defaults" do
      {:ok, ref} = Lux.Memory.initialize(backend: MockMemory)
      assert {:ok, _entry} = Lux.Memory.add(ref, "test content")

      assert_received {:memory_add, ^ref,
                       %{
                         content: "test content",
                         type: :observation,
                         metadata: %{},
                         timestamp: timestamp
                       }}
                      when is_integer(timestamp)
    end

    test "adds entry with custom type and metadata" do
      {:ok, ref} = Lux.Memory.initialize(backend: MockMemory)
      metadata = %{source: "test"}
      assert {:ok, _entry} = Lux.Memory.add(ref, "test content", :interaction, metadata)

      assert_received {:memory_add, ^ref,
                       %{
                         content: "test content",
                         type: :interaction,
                         metadata: ^metadata,
                         timestamp: timestamp
                       }}
                      when is_integer(timestamp)
    end

    test "retrieves recent entries" do
      {:ok, ref} = Lux.Memory.initialize(backend: MockMemory)
      assert {:ok, []} = Lux.Memory.recent(ref, 5)
      assert_received {:memory_recent, ^ref, 5}
    end

    test "retrieves entries by time window" do
      {:ok, ref} = Lux.Memory.initialize(backend: MockMemory)
      start_time = DateTime.utc_now()
      end_time = DateTime.add(start_time, 3600)
      assert {:ok, []} = Lux.Memory.window(ref, start_time, end_time)
      assert_received {:memory_window, ^ref, ^start_time, ^end_time}
    end

    test "searches entries" do
      {:ok, ref} = Lux.Memory.initialize(backend: MockMemory)
      assert {:ok, []} = Lux.Memory.search(ref, "test")
      assert_received {:memory_search, ^ref, "test"}
    end
  end

  describe "validation" do
    test "requires backend for initialization" do
      assert_raise KeyError, fn ->
        Lux.Memory.initialize([])
      end
    end

    test "requires positive integer for recent" do
      {:ok, ref} = Lux.Memory.initialize(backend: MockMemory)

      assert_raise FunctionClauseError, fn ->
        Lux.Memory.recent(ref, 0)
      end

      assert_raise FunctionClauseError, fn ->
        Lux.Memory.recent(ref, -1)
      end
    end
  end
end
