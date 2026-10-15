defmodule Lux.Web3.EventMonitorTest do
  use ExUnit.Case, async: false
  alias Lux.Web3.EventMonitor

  setup do
    EventMonitor.init_store()
    :ets.delete_all_objects(:lux_web3_event_monitor_store)
    :ok
  end

  test "subscribes, filters, persists, dispatches webhooks, and replays contract events" do
    {:ok, sub} =
      EventMonitor.subscribe(%{
        chain: :base,
        contract_address: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
        event_signature: "Transfer(address,address,uint256)",
        filters: %{to: "0x3806cd592a508d1992ed007c2f53de251c2e7452"},
        webhook_url: "https://example.com/webhooks/events"
      })

    assert sub.active == true
    assert sub.event_signature == "Transfer(address,address,uint256)"

    test_pid = self()

    raw_logs = [
      %{
        transaction_hash: "0xabc1",
        log_index: 0,
        block_number: 100,
        args: %{from: "0x111", to: "0x3806cd592a508d1992ed007c2f53de251c2e7452", value: 500}
      },
      %{
        transaction_hash: "0xabc2",
        log_index: 1,
        block_number: 101,
        args: %{from: "0x111", to: "0x9999999999999999999999999999999999999999", value: 100}
      }
    ]

    {:ok, events} =
      EventMonitor.process_logs(sub.id, raw_logs,
        webhook_fn: fn url, ev ->
          send(test_pid, {:webhook_sent, url, ev.id})
          :ok
        end
      )

    assert length(events) == 1
    assert hd(events).transaction_hash == "0xabc1"
    assert_received {:webhook_sent, "https://example.com/webhooks/events", "0xabc1:0"}

    replayed = EventMonitor.replay_events(sub.id, from_block: 90, to_block: 105)
    assert length(replayed) == 1

    summary = EventMonitor.dashboard_summary()
    assert summary.total_subscriptions == 1
    assert summary.total_events_captured == 1
    assert summary.events_by_chain[:base] == 1
  end

  test "syncs historical logs across chunked block ranges" do
    {:ok, sub} =
      EventMonitor.subscribe(%{
        chain: :ethereum,
        contract_address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        event_signature: "Approval(address,address,uint256)"
      })

    {:ok, synced} =
      EventMonitor.sync_historical(sub.id, 1_000, 2_500,
        chunk_size: 1_000,
        fetcher_fn: fn _sub, from_b, _to_b ->
          {:ok, [%{transaction_hash: "0xtx_#{from_b}", log_index: 0, block_number: from_b, args: %{}}]}
        end
      )

    assert length(synced) == 2
  end
end
