# Smart Contract Event Monitoring

## Overview

A robust event monitoring system for tracking and processing smart contract events across EVM chains with subscription management, automatic decoding, and real-time notifications.

## Quick Start

### Decoding Events

The `EventDecoder` automatically recognizes common ERC-20/721/1155 events:

```elixir
alias Lux.Integrations.Web3.Events.EventDecoder

log = %{
  "topics" => [
    "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
    "0x000000000000000000000000sender_address",
    "0x000000000000000000000000receiver_address"
  ],
  "data" => "0x00000000000000000000000000000000000000000000000000000000000003e8",
  "address" => "0xdAC17F958D2ee523a2206206994597C13D831ec7"
}

event = EventDecoder.decode(log)
# => %{type: :transfer, from: "0xsender...", to: "0xreceiver...", value: 1000}
```

**Supported event types:** Transfer, Approval, Deposit, Withdrawal, Swap, Sync, TransferSingle, TransferBatch

### Managing Subscriptions

```elixir
alias Lux.Integrations.Web3.Events.SubscriptionManager

{:ok, pid} = SubscriptionManager.start_link()

# Subscribe to USDT transfers
{:ok, sub} = SubscriptionManager.subscribe(pid, %{
  contract_address: "0xdAC17F958D2ee523a2206206994597C13D831ec7",
  chain: :ethereum,
  event_types: [:transfer]
})

# List all subscriptions
subs = SubscriptionManager.list(pid)

# Filter by chain
eth_subs = SubscriptionManager.for_chain(pid, :ethereum)

# Unsubscribe
:ok = SubscriptionManager.unsubscribe(pid, sub.id)
```

### Real-Time Monitoring

```elixir
alias Lux.Integrations.Web3.Events.EventMonitor

{:ok, monitor} = EventMonitor.start_link(
  chain: :ethereum,
  rpc_url: "https://eth.llamarpc.com",
  poll_interval_ms: 15_000
)

# Watch a contract with handler callback
{:ok, watch_id} = EventMonitor.add_watch(monitor, %{
  address: "0xdAC17F958D2ee523a2206206994597C13D831ec7",
  topics: ["0xddf252ad..."],
  handler: fn event ->
    IO.puts("Transfer: #{event.from} -> #{event.to} (#{event.value})")
  end
})

# Query stored events
{:ok, events} = EventMonitor.get_events(monitor, type: :transfer, limit: 50)

# Check status
status = EventMonitor.status(monitor)
# => %{chain: :ethereum, watches: 1, events_stored: 42}
```

### Fetching Historical Events

```elixir
alias Lux.Lenses.Web3.Events.GetContractEvents

{:ok, result} = GetContractEvents.focus(%{
  rpc_url: "https://eth.llamarpc.com",
  address: "0xdAC17F958D2ee523a2206206994597C13D831ec7",
  from_block: 19000000,
  to_block: 19001000,
  event_type: "transfer"
})
# => %{events: [...], count: 150}
```

### Using the Prism Interface

```elixir
alias Lux.Prisms.Web3.Events.ManageSubscription

# Subscribe
{:ok, result} = ManageSubscription.handler(%{
  action: "subscribe",
  contract_address: "0xUSDT...",
  chain: :ethereum,
  event_types: [:transfer, :approval]
}, [])

# List all
{:ok, result} = ManageSubscription.handler(%{action: "list"}, [])
```

## Architecture

```
EventDecoder
├── 8 known event signatures (ERC-20/721/1155)
├── Address/uint256 parameter decoding
└── Extensible for custom ABIs

SubscriptionManager (GenServer)
├── Per-contract subscriptions
├── Per-chain filtering
└── Webhook URL support

EventMonitor (GenServer)
├── Real-time log polling
├── Handler callbacks per watch
├── Event storage and retrieval
└── Configurable poll interval

Lenses: GetContractEvents
Prisms: ManageSubscription
```
