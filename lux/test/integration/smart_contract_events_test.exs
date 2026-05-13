defmodule Lux.Integration.SmartContractEventsTest do
  use IntegrationCase, async: false

  setup do
    name = :"event_monitor_integration_#{System.unique_integer([:positive])}"
    monitor = start_supervised!({Lux.EventMonitor, name: name})
    %{monitor: monitor}
  end

  test "monitors contract events from historical sync through realtime replay", %{monitor: monitor} do
    {:ok, subscription} =
      Lux.EventMonitor.subscribe(monitor, %{
        name: "USDC transfers",
        chain_id: 1,
        address: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
        topics: [transfer_topic()],
        event_abi: transfer_abi(),
        start_block: 1
      })

    assert {:ok, %{fetched: 1, matched: 1, stored: 1}} =
             Lux.EventMonitor.sync_history(monitor, subscription.id,
               from_block: 1,
               to_block: 1,
               logs: [transfer_log("0xhist", "0x1", "0x0")]
             )

    assert {:ok, %{matched: 1, stored: 1, events: [event]}} =
             Lux.EventMonitor.process_event(monitor, transfer_log("0xlive", "0x2", "0x1"), notify: false)

    assert event.decoded.event == "Transfer"
    assert event.decoded.args["value"] == 100

    assert {:ok, events} = Lux.EventMonitor.replay_events(monitor, subscription_id: subscription.id)
    assert Enum.map(events, & &1.transaction_hash) == ["0xhist", "0xlive"]

    dashboard = Lux.EventMonitor.dashboard(monitor)
    assert dashboard.active_subscriptions == 1
    assert dashboard.stored_events == 2
    assert [%{cursor_block: 2}] = dashboard.cursors
  end

  defp transfer_topic,
    do: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"

  defp transfer_abi do
    [
      %{
        "anonymous" => false,
        "inputs" => [
          %{"indexed" => true, "name" => "from", "type" => "address"},
          %{"indexed" => true, "name" => "to", "type" => "address"},
          %{"indexed" => false, "name" => "value", "type" => "uint256"}
        ],
        "name" => "Transfer",
        "type" => "event"
      }
    ]
  end

  defp transfer_log(tx_hash, block_number, log_index) do
    %{
      "address" => "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
      "topics" => [
        transfer_topic(),
        "0x0000000000000000000000001111111111111111111111111111111111111111",
        "0x0000000000000000000000002222222222222222222222222222222222222222"
      ],
      "transactionHash" => tx_hash,
      "logIndex" => log_index,
      "blockNumber" => block_number,
      "data" => "0x0000000000000000000000000000000000000000000000000000000000000064"
    }
  end
end
