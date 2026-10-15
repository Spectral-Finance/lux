# Smart Contract Event Monitoring System

Lux includes a Smart Contract Event Monitoring System (`Lux.Web3.EventMonitor`) for subscribing to, filtering, decoding, persisting, replaying, and dispatching webhook alerts for smart contract events across multiple EVM chains.

## Core Modules

- **`Lux.Web3.EventMonitor`** — Subscription management, real-time polling, chunked historical syncing, raw log ingestion, and monitoring dashboard metrics
- **`Lux.Web3.EventMonitor.Decoder`** — Standard and custom event ABI registration (`Transfer`, `Approval`, `Swap`, `OwnershipTransferred`) and topic/data decoding
- **`Lux.Web3.EventMonitor.Filter`** — Declarative event filtering and parameter pattern matching (`:eq`, `:neq`, `:gt`, `:gte`, `:lt`, `:lte`, `:in`, `:contains`, custom predicates)
- **`Lux.Web3.EventMonitor.Webhook`** — HMAC-SHA256 signed webhook delivery (`x-lux-signature-256`) with retry and delivery logging
- **`Lux.Web3.EventMonitor.Store`** — Deduplicated ETS event store, per-subscription block checkpoints, and chronological event replay
- **`Lux.Prisms.Web3.EventMonitorPrism`** — Agent tool Prism for managing subscriptions and querying contract events

## Usage Examples

```elixir
# 1. Create a subscription with parameter pattern matching and HMAC webhook notifications
{:ok, sub} = Lux.Web3.EventMonitor.subscribe(
  name: "High-Value USDC Transfers",
  chain: :ethereum,
  contracts: ["0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"],
  event_names: ["Transfer"],
  param_patterns: %{value: {:gte, 100_000_000_000}},
  subscriber_pid: self(),
  webhook_url: "https://hooks.example.com/usdc-alerts",
  webhook_secret: "webhook-signing-secret"
)

# 2. Poll real-time logs or sync a historical block range
{:ok, new_events} = Lux.Web3.EventMonitor.poll_subscription(sub.id)
{:ok, historical} = Lux.Web3.EventMonitor.sync_historical(sub.id, 19_000_000, 19_010_000)

# 3. Replay persisted events and inspect the monitoring dashboard
{:ok, replayed} = Lux.Web3.EventMonitor.replay([subscription_id: sub.id], self())
dashboard = Lux.Web3.EventMonitor.dashboard_snapshot()
```
