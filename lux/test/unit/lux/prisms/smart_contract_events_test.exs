defmodule Lux.Prisms.SmartContractEventsTest do
  use UnitCase, async: false

  alias Lux.Prisms.SmartContractEvents.{CreateSubscription, ProcessEvent, SyncHistoricalEvents}

  setup do
    name = :"event_monitor_prisms_#{System.unique_integer([:positive])}"
    monitor = start_supervised!({Lux.EventMonitor, name: name})
    snapshot = Lux.EventMonitor.snapshot(monitor)
    Lux.EventMonitor.restore(snapshot)
    :ok
  end

  test "create, process, and sync prisms call the default monitor" do
    topic = "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"

    assert {:ok, subscription} =
             CreateSubscription.run(%{
               address: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
               topics: [topic],
               start_block: 1
             })

    log = %{
      "address" => "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
      "topics" => [topic],
      "transactionHash" => "0xdef",
      "logIndex" => "0x0",
      "blockNumber" => "0x2",
      "data" => "0x"
    }

    assert {:ok, %{matched: 1, stored: 1}} =
             ProcessEvent.run(%{event: log, notify: false})

    assert {:ok, %{fetched: 1, matched: 1, from_block: 3, to_block: 3}} =
             SyncHistoricalEvents.run(%{
               "subscription_id" => subscription.id,
               "from_block" => 3,
               "to_block" => 3,
               "logs" => [%{log | "transactionHash" => "0xfeed", "blockNumber" => "0x3"}]
             })
  end
end
