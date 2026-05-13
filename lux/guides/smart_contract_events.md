# Smart Contract Event Monitoring

Lux includes an in-process event monitor for agents that need contract event subscriptions,
historical syncing, real-time polling, event replay, webhook notifications, and dashboard
state.

```elixir
{:ok, sub} =
  Lux.EventMonitor.subscribe(%{
    name: "USDC transfers",
    chain_id: 1,
    address: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
    topics: ["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"],
    event_abi: [
      %{
        "type" => "event",
        "name" => "Transfer",
        "inputs" => [
          %{"indexed" => true, "name" => "from", "type" => "address"},
          %{"indexed" => true, "name" => "to", "type" => "address"},
          %{"indexed" => false, "name" => "value", "type" => "uint256"}
        ]
      }
    ],
    start_block: 20_000_000,
    webhook_url: "https://example.com/lux-events"
  })
```

When an `event_abi` is present, matched logs are decoded with `ABI.Event`; otherwise
the monitor keeps the raw signature topic and data.

Historical syncing uses `Lux.Lenses.Etherscan.GetLogs` by default:

```elixir
Lux.EventMonitor.sync_history(sub.id, from_block: 20_000_000, to_block: 20_000_500)
```

For local testing or custom RPC pipelines, pass logs or a fetcher:

```elixir
Lux.EventMonitor.sync_history(sub.id,
  from_block: 1,
  to_block: 2,
  logs: [
    %{
      "address" => "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
      "topics" => ["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"],
      "transactionHash" => "0xabc",
      "logIndex" => "0x0",
      "blockNumber" => "0x1",
      "data" => "0x"
    }
  ]
)
```

Real-time monitoring can be driven by a polling loop or by pushing fresh logs into the
monitor as they arrive from a websocket or RPC client:

```elixir
Lux.EventMonitor.poll_once(sub.id, to_block: 20_000_600)
Lux.EventMonitor.process_event(raw_log)
```

Agents can inspect stored events and dashboard status through local lenses:

```elixir
Lux.Lenses.SmartContractEvents.Dashboard.focus()
Lux.Lenses.SmartContractEvents.ReplayEvents.focus(%{subscription_id: sub.id, limit: 25})
```

The monitor also exposes prisms:

* `Lux.Prisms.SmartContractEvents.CreateSubscription`
* `Lux.Prisms.SmartContractEvents.ProcessEvent`
* `Lux.Prisms.SmartContractEvents.SyncHistoricalEvents`
