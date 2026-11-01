defmodule Lux.Web3.EventMonitor.EventStoreTest do
  use ExUnit.Case, async: false

  alias Lux.Web3.EventMonitor.EventStore
  alias Lux.Web3.EventMonitor.Schemas.MonitoredEvent

  setup do
    server_name = :"store_test_#{System.unique_integer([:positive])}"
    {:ok, pid} = EventStore.start_link(name: server_name, max_events: 10)
    %{server: server_name, pid: pid}
  end

  describe "EventStore operations" do
    test "stores, queries, and replays events", %{server: server} do
      events =
        for i <- 1..5 do
          %MonitoredEvent{
            id: "evt_#{i}",
            subscription_id: "sub_1",
            chain_id: 1,
            chain: :ethereum,
            contract_address: "0xdac17f958d2ee523a2206206994597c13d831ec7",
            event_name: "Transfer",
            tx_hash: "0xhash_#{i}",
            block_number: 1000 + i,
            log_index: i,
            decoded_params: %{value: i * 100}
          }
        end

      {:ok, count} = EventStore.store_batch(server, events)
      assert count == 5
      assert EventStore.count(server) == 5

      # Query
      {results, total} = EventStore.query_events(server, %{subscription_id: "sub_1"}, %{limit: 3})
      assert total == 5
      assert length(results) == 3
      assert hd(results).block_number == 1005

      # Replay
      agent_mailbox = self()
      {:ok, replayed_count} =
        EventStore.replay_events(server, %{subscription_id: "sub_1"}, fn ev ->
          send(agent_mailbox, {:replayed, ev.id})
        end)

      assert replayed_count == 5
      assert_received {:replayed, "evt_1"}
      assert_received {:replayed, "evt_5"}
    end

    test "respects ring buffer max_events limit", %{server: server} do
      # Capacity is 10
      events =
        for i <- 1..15 do
          %MonitoredEvent{
            id: "overflow_evt_#{i}",
            subscription_id: "sub_1",
            chain_id: 1,
            chain: :ethereum,
            contract_address: "0xdac",
            tx_hash: "0x#{i}",
            block_number: i
          }
        end

      EventStore.store_batch(server, events)
      assert EventStore.count(server) <= 10
    end
  end
end
