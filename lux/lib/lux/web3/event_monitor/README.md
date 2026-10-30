# Smart Contract Event Monitoring System for Lux

A high-throughput, OTP-compliant event monitoring and processing engine for smart contracts across EVM networks (Ethereum, Polygon, Arbitrum, Base, etc.).

## Features
- **Contract Event Subscriptions:** Dynamic subscription and unsubscription of contract addresses and topics.
- **Real-Time Polling & Reorg Protection:** Block confirmation depth buffer preventing reorg false positives.
- **Historical Event Syncing:** Chunked batch syncing (`from_block` to `to_block`) with rate-limit and RPC timeout resilience.
- **Pattern Matching & Custom Filtering:** Topic filtering (`topic0`, `topic1`, `topic2`) and functional predicates.
- **ETS Persistence & Replay Engine:** Fast memory-mapped event storage, deduplication by `chain_id:tx_hash:log_index`, and event replay.
- **Webhook Notifier:** Resilient event dispatch to HTTP webhooks with exponential backoff retries via `Req`.

---

## Quickstart

### 1. Start EventMonitor GenServer
```elixir
{:ok, pid} = Lux.Web3.EventMonitor.start_link(
  rpc_url: "https://polygon-bor-rpc.publicnode.com",
  chain_id: 137,
  poll_interval: 3_000,
  confirmations: 2
)
```

### 2. Subscribe to Contract Events
```elixir
Lux.Web3.EventMonitor.subscribe(pid, %{
  address: "0x6e7a5fafcec6bb1e78bae2a1f0b612012bf14827",
  webhook_url: "https://api.yourdomain.com/webhooks/contract-events",
  topics: ["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"]
})
```

### 3. Historical Event Sync
```elixir
{:ok, summary} = Lux.Web3.EventMonitor.sync_historical(
  pid,
  "0x6e7a5fafcec6bb1e78bae2a1f0b612012bf14827",
  50_000_000,
  50_010_000
)
```

### 4. Query & Replay Stored Events
```elixir
events = Lux.Web3.EventMonitor.EventStore.list_events(contract: "0x6e7a5fafcec6bb1e78bae2a1f0b612012bf14827")

{:ok, count} = Lux.Web3.EventMonitor.EventStore.replay_events([contract: "0x6e7a5fafcec6bb1e78bae2a1f0b612012bf14827"], fn event ->
  IO.inspect(event, label: "Replayed Event")
end)
```

---

## Testing
Run the automated test suite:
```bash
mix test test/lux/web3/event_monitor_test.exs
```
