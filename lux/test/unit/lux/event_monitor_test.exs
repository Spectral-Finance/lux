defmodule Lux.EventMonitorTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.SmartContractEvents.{Dashboard, ReplayEvents}

  setup do
    Req.Test.verify_on_exit!()
    name = :"event_monitor_#{System.unique_integer([:positive])}"
    monitor = start_supervised!({Lux.EventMonitor, name: name})
    %{monitor: monitor}
  end

  test "subscribes, filters, decodes, stores, deduplicates, and replays events", %{monitor: monitor} do
    {:ok, subscription} =
      Lux.EventMonitor.subscribe(monitor, %{
        name: "USDC transfers",
        chain_id: 1,
        address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        topics: [transfer_topic()],
        event_abi: %{
          name: "Transfer",
          inputs: [
            %{name: "from", indexed: true},
            %{name: "to", indexed: true},
            %{name: "value", indexed: false}
          ]
        }
      })

    log = transfer_log(block: "0x10", log_index: "0x0")

    assert {:ok, %{matched: 1, stored: 1, events: [event]}} =
             Lux.EventMonitor.process_event(monitor, log, notify: false)

    assert event.subscription_id == subscription.id
    assert event.block_number == 16
    assert event.decoded.event == "Transfer"
    assert event.decoded.indexed["from"] == Enum.at(log["topics"], 1)

    assert {:ok, %{matched: 1, stored: 0, events: []}} =
             Lux.EventMonitor.process_event(monitor, log, notify: false)

    assert {:ok, [replayed]} =
             Lux.EventMonitor.replay_events(monitor, subscription_id: subscription.id)

    assert replayed.id == event.id

    assert {:ok, updated_subscription} = Lux.EventMonitor.get_subscription(monitor, subscription.id)
    assert updated_subscription.cursor_block == 16
  end

  test "decodes full ABI event definitions", %{monitor: monitor} do
    {:ok, _subscription} =
      Lux.EventMonitor.subscribe(monitor, %{
        name: "Decoded USDC transfers",
        chain_id: 1,
        address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        topics: [transfer_topic()],
        event_abi: full_transfer_abi()
      })

    assert {:ok, %{events: [event]}} =
             Lux.EventMonitor.process_event(monitor, transfer_log(), notify: false)

    assert event.decoded.event == "Transfer"
    assert event.decoded.args["from"] == "0x1111111111111111111111111111111111111111"
    assert event.decoded.args["to"] == "0x2222222222222222222222222222222222222222"
    assert event.decoded.args["value"] == 100
    assert event.decoded.indexed["from"] == "0x1111111111111111111111111111111111111111"
    assert event.decoded.non_indexed["value"] == 100
  end

  test "syncs historical logs and returns dashboard data", %{monitor: monitor} do
    {:ok, subscription} =
      Lux.EventMonitor.subscribe(monitor, %{
        chain_id: 1,
        address: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
        topics: [transfer_topic()],
        start_block: 1
      })

    {:ok, other_subscription} =
      Lux.EventMonitor.subscribe(monitor, %{
        chain_id: 1,
        address: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
        topics: [transfer_topic()],
        start_block: 1
      })

    logs = [
      transfer_log(block: "0x2", log_index: "0x0"),
      transfer_log(block: "0x3", log_index: "0x1")
    ]

    assert {:ok, result} =
             Lux.EventMonitor.sync_history(monitor, subscription.id,
               from_block: 2,
               to_block: 3,
               logs: logs
             )

    assert result.fetched == 2
    assert result.matched == 2
    assert result.stored == 2

    assert {:ok, []} =
             Lux.EventMonitor.replay_events(monitor, subscription_id: other_subscription.id)

    dashboard = Lux.EventMonitor.dashboard(monitor)
    assert dashboard.subscriptions == 2
    assert dashboard.active_subscriptions == 2
    assert dashboard.stored_events == 2
    assert Enum.any?(dashboard.cursors, &(&1.id == subscription.id and &1.cursor_block == 3))
  end

  test "posts matching realtime events to a webhook", %{monitor: monitor} do
    Application.put_env(:lux, :event_monitor_req_options, plug: {Req.Test, __MODULE__})

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/hooks/events"
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      payload = Jason.decode!(body)

      assert payload["subscription_id"]
      assert payload["event"]["transaction_hash"] == "0xabc"

      Req.Test.json(conn, %{"ok" => true})
    end)

    Req.Test.allow(__MODULE__, self(), monitor)

    {:ok, _subscription} =
      Lux.EventMonitor.subscribe(monitor, %{
        address: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
        topics: [transfer_topic()],
        webhook_url: "https://webhook.test/hooks/events"
      })

    assert {:ok, %{stored: 1, events: [event]}} =
             Lux.EventMonitor.process_event(monitor, transfer_log(), notify: true)

    assert event.notification == {:ok, 200}
  after
    Application.delete_env(:lux, :event_monitor_req_options)
  end

  test "local lenses expose dashboard and replay", %{monitor: monitor} do
    {:ok, subscription} =
      Lux.EventMonitor.subscribe(monitor, %{
        address: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
        topics: [transfer_topic()]
      })

    assert {:ok, %{stored: 1}} =
             Lux.EventMonitor.process_event(monitor, transfer_log(), notify: false)

    snapshot = Lux.EventMonitor.snapshot(monitor)
    assert :ok = Lux.EventMonitor.restore(snapshot)

    assert {:ok, dashboard} = Dashboard.focus()
    assert dashboard.stored_events >= 1

    assert {:ok, events} =
             ReplayEvents.focus(%{
               subscription_id: subscription.id,
               limit: 1
             })

    assert length(events) == 1

    assert {:ok, events} =
             ReplayEvents.focus(%{
               "subscription_id" => subscription.id,
               "limit" => 1
             })

    assert length(events) == 1
  end

  defp transfer_topic,
    do: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"

  defp full_transfer_abi do
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

  defp transfer_log(opts \\ []) do
    %{
      "address" => "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
      "topics" => [
        transfer_topic(),
        "0x0000000000000000000000001111111111111111111111111111111111111111",
        "0x0000000000000000000000002222222222222222222222222222222222222222"
      ],
      "transactionHash" => "0xabc",
      "logIndex" => Keyword.get(opts, :log_index, "0x0"),
      "blockNumber" => Keyword.get(opts, :block, "0x1"),
      "data" => "0x0000000000000000000000000000000000000000000000000000000000000064"
    }
  end
end
