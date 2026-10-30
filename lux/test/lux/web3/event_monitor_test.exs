defmodule Lux.Web3.EventMonitorTest do
  use ExUnit.Case, async: false

  alias Lux.Web3.EventMonitor
  alias Lux.Web3.EventMonitor.EventStore

  setup do
    case Process.whereis(EventStore) do
      nil -> EventStore.start_link([])
      _pid -> :ok
    end
    :ok
  end

  test "event store saves, deduplicates and retrieves events" do
    sample_event = %{
      chain_id: 137,
      transaction_hash: "0x123abc",
      log_index: 0,
      address: "0x6e7a5fafcec6bb1e78bae2a1f0b612012bf14827",
      block_number: 50000000,
      data: "0x0"
    }

    assert {:ok, _id} = EventStore.save_event(sample_event)
    assert {:duplicate, _id} = EventStore.save_event(sample_event)

    events = EventStore.list_events(contract: "0x6e7a5fafcec6bb1e78bae2a1f0b612012bf14827")
    assert length(events) == 1
  end

  test "event monitor manages subscriptions lifecycle" do
    {:ok, pid} = EventMonitor.start_link(name: :test_monitor, poll_interval: 60_000)

    contract = "0x6e7a5fafcec6bb1e78bae2a1f0b612012bf14827"
    assert {:ok, ^contract} = EventMonitor.subscribe(pid, %{
      address: contract,
      webhook_url: "https://example.com/webhook"
    })

    status = EventMonitor.status(pid)
    assert status.subscriptions_count == 1

    assert :ok = EventMonitor.unsubscribe(pid, contract)
    status_after = EventMonitor.status(pid)
    assert status_after.subscriptions_count == 0

    GenServer.stop(pid)
  end
end
