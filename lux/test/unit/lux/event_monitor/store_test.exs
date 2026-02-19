defmodule Lux.EventMonitor.StoreTest do
  use UnitCase, async: false

  alias Lux.EventMonitor.EventLog
  alias Lux.EventMonitor.Store

  setup do
    name = :"store_test_#{System.unique_integer([:positive])}"
    {:ok, pid} = Store.start_link(name: name, max_events: 100)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    %{store: name}
  end

  defp make_event(attrs \\ %{}) do
    %EventLog{
      address: Map.get(attrs, :address, "0xdead"),
      topics: Map.get(attrs, :topics, ["0xtopic0"]),
      data: "0x",
      block_number: Map.get(attrs, :block_number, 100),
      transaction_hash: Map.get(attrs, :tx_hash, "0x#{:crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower)}"),
      log_index: Map.get(attrs, :log_index, 0),
      chain_id: Map.get(attrs, :chain_id, 1),
      event_name: Map.get(attrs, :event_name, "Transfer"),
      decoded_params: Map.get(attrs, :decoded_params, %{"value" => 1000}),
      timestamp: Map.get(attrs, :timestamp, 1_700_000_000)
    }
  end

  describe "insert/2 and count/1" do
    test "inserts a single event", %{store: store} do
      event = make_event()
      assert :ok = Store.insert(store, event)
      assert Store.count(store) == 1
    end

    test "deduplicates events with same key", %{store: store} do
      event = make_event(%{tx_hash: "0xsame", log_index: 0, chain_id: 1})
      Store.insert(store, event)
      Store.insert(store, event)
      assert Store.count(store) == 1
    end
  end

  describe "insert_batch/2" do
    test "inserts multiple events", %{store: store} do
      events = for i <- 1..10, do: make_event(%{block_number: i})
      assert :ok = Store.insert_batch(store, events)
      assert Store.count(store) == 10
    end
  end

  describe "query/2" do
    setup %{store: store} do
      events = [
        make_event(%{address: "0xusdc", event_name: "Transfer", block_number: 100, chain_id: 1}),
        make_event(%{address: "0xusdc", event_name: "Approval", block_number: 200, chain_id: 1}),
        make_event(%{address: "0xweth", event_name: "Transfer", block_number: 300, chain_id: 1}),
        make_event(%{address: "0xmatic", event_name: "Transfer", block_number: 400, chain_id: 137})
      ]

      Store.insert_batch(store, events)
      %{events: events}
    end

    test "queries all events with no filter", %{store: store} do
      {:ok, results} = Store.query(store)
      assert length(results) == 4
    end

    test "filters by address", %{store: store} do
      {:ok, results} = Store.query(store, %{address: "0xusdc"})
      assert length(results) == 2
    end

    test "filters by event name", %{store: store} do
      {:ok, results} = Store.query(store, %{event_name: "Transfer"})
      assert length(results) == 3
    end

    test "filters by chain_id", %{store: store} do
      {:ok, results} = Store.query(store, %{chain_id: 137})
      assert length(results) == 1
    end

    test "filters by block range", %{store: store} do
      {:ok, results} = Store.query(store, %{from_block: 200, to_block: 300})
      assert length(results) == 2
    end

    test "combines multiple filters", %{store: store} do
      {:ok, results} = Store.query(store, %{address: "0xusdc", event_name: "Transfer"})
      assert length(results) == 1
    end

    test "supports limit and offset", %{store: store} do
      {:ok, results} = Store.query(store, %{limit: 2})
      assert length(results) == 2

      {:ok, results} = Store.query(store, %{limit: 2, offset: 2})
      assert length(results) == 2
    end

    test "supports ascending order", %{store: store} do
      {:ok, results} = Store.query(store, %{order: :asc})
      blocks = Enum.map(results, & &1.block_number)
      assert blocks == Enum.sort(blocks)
    end

    test "supports descending order (default)", %{store: store} do
      {:ok, results} = Store.query(store, %{order: :desc})
      blocks = Enum.map(results, & &1.block_number)
      assert blocks == Enum.sort(blocks, :desc)
    end
  end

  describe "clear/1" do
    test "removes all events", %{store: store} do
      events = for i <- 1..5, do: make_event(%{block_number: i})
      Store.insert_batch(store, events)
      assert Store.count(store) == 5

      assert :ok = Store.clear(store)
      assert Store.count(store) == 0
    end
  end

  describe "prune/3" do
    test "removes events before specified block on a chain", %{store: store} do
      events = [
        make_event(%{block_number: 100, chain_id: 1}),
        make_event(%{block_number: 200, chain_id: 1}),
        make_event(%{block_number: 300, chain_id: 1}),
        make_event(%{block_number: 100, chain_id: 137})
      ]

      Store.insert_batch(store, events)
      assert Store.count(store) == 4

      pruned = Store.prune(store, 1, 250)
      assert pruned == 2
      assert Store.count(store) == 2
    end

    test "does not prune events from other chains", %{store: store} do
      events = [
        make_event(%{block_number: 100, chain_id: 1}),
        make_event(%{block_number: 100, chain_id: 137})
      ]

      Store.insert_batch(store, events)
      pruned = Store.prune(store, 1, 200)
      assert pruned == 1
      assert Store.count(store) == 1
    end
  end

  describe "max_events enforcement" do
    test "enforces max_events limit" do
      name = :"store_limit_test_#{System.unique_integer([:positive])}"
      {:ok, pid} = Store.start_link(name: name, max_events: 5)

      events = for i <- 1..10, do: make_event(%{block_number: i})
      Store.insert_batch(name, events)

      # Should have at most 5 events
      assert Store.count(name) <= 5

      GenServer.stop(pid)
    end
  end
end
