defmodule Lux.Integrations.Web3.Events.EventStoreTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Web3.Events.EventStore

  setup do
    {:ok, pid} = EventStore.start_link(name: :"test_#{:rand.uniform(1_000_000)}", max_events: 100)
    %{pid: pid}
  end

  test "store and query events", %{pid: pid} do
    event = %{type: :transfer, address: "0xtoken", block_number: 100, log_index: 0, from: "0xa", to: "0xb"}
    {:ok, _key} = EventStore.store(pid, event)

    assert EventStore.count(pid) == 1
    {:ok, events} = EventStore.query(pid)
    assert length(events) == 1
    assert hd(events).type == :transfer
  end

  test "store batch", %{pid: pid} do
    events = for i <- 1..10 do
      %{type: :transfer, address: "0xtoken", block_number: 100 + i, log_index: i}
    end
    {:ok, keys} = EventStore.store_batch(pid, events)
    assert length(keys) == 10
    assert EventStore.count(pid) == 10
  end

  test "query with type filter", %{pid: pid} do
    EventStore.store(pid, %{type: :transfer, address: "0xa", block_number: 1, log_index: 1})
    EventStore.store(pid, %{type: :approval, address: "0xa", block_number: 2, log_index: 2})
    EventStore.store(pid, %{type: :transfer, address: "0xb", block_number: 3, log_index: 3})

    {:ok, transfers} = EventStore.query(pid, %{type: :transfer})
    assert length(transfers) == 2
  end

  test "query with address filter", %{pid: pid} do
    EventStore.store(pid, %{type: :transfer, address: "0xa", block_number: 1, log_index: 1})
    EventStore.store(pid, %{type: :transfer, address: "0xb", block_number: 2, log_index: 2})

    {:ok, events} = EventStore.query(pid, %{address: "0xa"})
    assert length(events) == 1
  end

  test "query with block range", %{pid: pid} do
    for i <- 1..20 do
      EventStore.store(pid, %{type: :transfer, address: "0xa", block_number: i * 10, log_index: i})
    end

    {:ok, events} = EventStore.query(pid, %{from_block: 50, to_block: 100})
    assert Enum.all?(events, &(&1.block_number >= 50 and &1.block_number <= 100))
  end

  test "clear removes all events", %{pid: pid} do
    EventStore.store(pid, %{type: :transfer, address: "0xa", block_number: 1, log_index: 1})
    assert EventStore.count(pid) == 1
    :ok = EventStore.clear(pid)
    assert EventStore.count(pid) == 0
  end

  test "export returns all events", %{pid: pid} do
    for i <- 1..5 do
      EventStore.store(pid, %{type: :transfer, address: "0xa", block_number: i, log_index: i})
    end
    {:ok, events} = EventStore.export(pid)
    assert length(events) == 5
  end

  test "evicts oldest when max_events exceeded", %{pid: pid} do
    # max_events is 100, insert 110
    for i <- 1..110 do
      EventStore.store(pid, %{type: :transfer, address: "0xa", block_number: i, log_index: i})
    end
    # After eviction, should be <= 100
    assert EventStore.count(pid) <= 100
  end
end
