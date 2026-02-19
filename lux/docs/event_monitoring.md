# Smart Contract Event Monitoring System

## Overview

The Smart Contract Event Monitoring System provides comprehensive real-time and historical event monitoring for EVM-compatible blockchains. It integrates deeply with the Lux framework's Prism, Lens, Beam, and Signal architecture.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   EventMonitor                       │
│                                                      │
│  ┌─────────────┐  ┌──────────┐  ┌───────────────┐  │
│  │ Subscriptions│  │  Decoder  │  │    Filter     │  │
│  └──────┬───────┘  └────┬─────┘  └──────┬────────┘  │
│         │               │               │            │
│  ┌──────▼───────────────▼───────────────▼────────┐  │
│  │              Poll Loop                         │  │
│  │  fetch logs → decode → filter → store → notify │  │
│  └───────────────────────────────────────────────-┘  │
│         │                               │            │
│  ┌──────▼───────┐            ┌──────────▼─────────┐ │
│  │    Store      │            │     Webhook        │ │
│  │   (ETS)       │            │    Manager         │ │
│  └───────────────┘            └────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

## Components

### Core Modules

| Module | Description |
|--------|-------------|
| `Lux.EventMonitor` | Central GenServer coordinating subscriptions, polling, decoding, and notifications |
| `Lux.EventMonitor.Subscription` | Subscription configuration and state management |
| `Lux.EventMonitor.EventLog` | Parsed event log data structure |
| `Lux.EventMonitor.Decoder` | ABI-based event decoding (keccak256 topic matching) |
| `Lux.EventMonitor.Filter` | Flexible event filtering with comparison operators |
| `Lux.EventMonitor.Store` | ETS-backed event persistence with querying |
| `Lux.EventMonitor.Webhook` | HTTP webhook notification delivery with retries |
| `Lux.EventMonitor.Supervisor` | OTP supervisor for the monitoring system |

### Lenses (Data Fetching)

| Lens | Description |
|------|-------------|
| `Lux.Lenses.EventMonitor.GetContractEventsLens` | Fetch historical events with decoding |
| `Lux.Lenses.EventMonitor.GetLatestBlockLens` | Get current block number on any chain |

### Prisms (Actions)

| Prism | Description |
|-------|-------------|
| `Lux.Prisms.EventMonitor.SubscribeEventsPrism` | Create event subscriptions |
| `Lux.Prisms.EventMonitor.UnsubscribeEventsPrism` | Remove event subscriptions |
| `Lux.Prisms.EventMonitor.QueryEventsPrism` | Query stored events |
| `Lux.Prisms.EventMonitor.RegisterWebhookPrism` | Register webhook notifications |

### Beams (Workflows)

| Beam | Description |
|------|-------------|
| `Lux.Beams.EventMonitor.EventMonitoringBeam` | Complete monitoring setup workflow |

### Signal Schemas

| Schema | Description |
|--------|-------------|
| `Lux.Schemas.EventMonitor.ContractEventSchema` | Validated signal schema for contract events |

## Quick Start

### 1. Start the Monitoring System

Add to your supervision tree:

```elixir
children = [
  {Lux.EventMonitor.Supervisor, []}
]
```

Or start manually:

```elixir
{:ok, _} = Lux.EventMonitor.Store.start_link()
{:ok, _} = Lux.EventMonitor.Webhook.start_link()
{:ok, _} = Lux.EventMonitor.start_link()
```

### 2. Subscribe to Events

```elixir
# ERC-20 Transfer events on USDC
{:ok, sub_id} = Lux.EventMonitor.subscribe(%{
  address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
  chain_id: 1,
  event_names: ["Transfer", "Approval"],
  abi: usdc_abi,
  from_block: 18_000_000,
  poll_interval_ms: 15_000
})
```

### 3. Register Webhooks

```elixir
{:ok, wh_id} = Lux.EventMonitor.register_webhook(%{
  url: "https://api.example.com/events",
  filter: %{event_name: "Transfer"},
  secret: "my_hmac_secret",
  max_retries: 5
})
```

### 4. Query Events

```elixir
{:ok, events} = Lux.EventMonitor.query_events(%{
  address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
  event_name: "Transfer",
  from_block: 18_000_000,
  to_block: 18_001_000,
  limit: 50,
  order: :desc
})
```

### 5. Real-Time Callbacks

```elixir
Lux.EventMonitor.on_event(fn event ->
  IO.puts("New event: #{event.event_name} on #{event.address}")
  IO.inspect(event.decoded_params)
end)
```

## Multi-Chain Support

The system supports all EVM chains via the Etherscan V2 API:

| Chain | ID |
|-------|----|
| Ethereum | 1 |
| Polygon | 137 |
| BSC | 56 |
| Arbitrum | 42161 |
| Optimism | 10 |
| Base | 8453 |
| Avalanche | 43114 |

```elixir
# Monitor the same contract on multiple chains
for {chain, chain_id} <- [{"ethereum", 1}, {"polygon", 137}] do
  Lux.EventMonitor.subscribe(%{
    address: "0xdead...",
    chain_id: chain_id,
    event_names: ["Transfer"],
    metadata: %{chain_name: chain}
  })
end
```

## Event Filtering

### Basic Filters

```elixir
filter = %{
  address: "0x...",
  event_name: "Transfer",
  chain_id: 1,
  from_block: 18_000_000,
  to_block: 18_001_000
}
```

### Parameter-Level Filters

```elixir
# Find large transfers
filter = %{
  event_name: "Transfer",
  params: %{
    "value" => {:gt, 1_000_000_000},      # > 1B (6 decimals = $1000+)
    "from" => {:neq, "0x0000..."}           # Not from zero address
  }
}
```

### Comparison Operators

| Operator | Example | Description |
|----------|---------|-------------|
| Exact | `"value" => 1000` | Exact match |
| `{:gt, n}` | `"value" => {:gt, 1000}` | Greater than |
| `{:lt, n}` | `"value" => {:lt, 1000}` | Less than |
| `{:gte, n}` | `"value" => {:gte, 1000}` | Greater or equal |
| `{:lte, n}` | `"value" => {:lte, 1000}` | Less or equal |
| `{:in, list}` | `"status" => {:in, [1, 2]}` | In list |
| `{:neq, v}` | `"from" => {:neq, "0x0"}` | Not equal |
| `{:regex, r}` | `"name" => {:regex, ~r/^Transfer/}` | Regex match |

### Combining Filters

```elixir
# AND: All criteria must match
filter = Lux.EventMonitor.Filter.all_of([
  %{event_name: "Transfer"},
  %{chain_id: 1},
  %{params: %{"value" => {:gt, 1_000_000}}}
])

# OR: Any criterion can match
filter = Lux.EventMonitor.Filter.any_of([
  %{event_name: "Transfer"},
  %{event_name: "Approval"}
])
```

## ABI Decoding

When an ABI is provided, the Decoder automatically:

1. Computes keccak256 hashes for event signatures
2. Matches raw log topics to known events
3. Decodes indexed parameters from topics
4. Decodes non-indexed parameters from the data field

```elixir
abi = [
  %{
    "type" => "event",
    "name" => "Transfer",
    "inputs" => [
      %{"name" => "from", "type" => "address", "indexed" => true},
      %{"name" => "to", "type" => "address", "indexed" => true},
      %{"name" => "value", "type" => "uint256", "indexed" => false}
    ]
  }
]

decoder = Lux.EventMonitor.Decoder.new(abi)
decoded = Lux.EventMonitor.Decoder.decode_log(decoder, raw_event)
# => %EventLog{event_name: "Transfer", decoded_params: %{"from" => "0x...", "to" => "0x...", "value" => 1000000}}
```

## Webhook Notifications

### Payload Format

```json
{
  "webhook_id": "wh_abc123",
  "event_id": "0xtxhash:0",
  "event_name": "Transfer",
  "address": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
  "block_number": 18000000,
  "chain_id": 1,
  "transaction_hash": "0x...",
  "log_index": 0,
  "decoded_params": {
    "from": "0x...",
    "to": "0x...",
    "value": 1000000
  },
  "data": "0x...",
  "topics": ["0xddf252..."],
  "timestamp": 1700000000,
  "removed": false
}
```

### HMAC Signature Verification

When a `secret` is provided, each webhook includes an `x-webhook-signature` header:

```elixir
# Verify webhook signature
expected = :crypto.mac(:hmac, :sha256, secret, body) |> Base.encode16(case: :lower)
actual = get_header(request, "x-webhook-signature")
Plug.Crypto.secure_compare(expected, actual)
```

### Retry Behavior

- Retries on HTTP 4xx/5xx responses
- Exponential backoff: `retry_delay_ms * (attempt + 1)`
- Configurable `max_retries` (default: 3)

## Using with Agents

### Via Prisms

```elixir
# In an agent's beam or tool definition
Lux.Prisms.EventMonitor.SubscribeEventsPrism.run(%{
  address: "0xdead...",
  chain_id: 1,
  event_names: ["Transfer"]
})
```

### Via Beams

```elixir
# Full monitoring setup in one workflow
Lux.Beams.EventMonitor.EventMonitoringBeam.run(%{
  address: "0xdead...",
  chain_id: 1,
  event_names: ["Transfer"],
  webhook_url: "https://api.example.com/events",
  webhook_secret: "secret123",
  from_block: 18_000_000
})
```

### Via Signal Schemas

```elixir
# Create validated event signals
signal = %Lux.Signal{
  payload: %{
    "address" => "0xdead...",
    "chain_id" => 1,
    "block_number" => 18_000_000,
    "transaction_hash" => "0xabc..."
  },
  schema_id: Lux.Schemas.EventMonitor.ContractEventSchema
}

{:ok, validated} = Lux.Schemas.EventMonitor.ContractEventSchema.validate(signal)
```

## Statistics

```elixir
stats = Lux.EventMonitor.stats()
# => %{
#   subscription_count: 3,
#   active_subscriptions: 2,
#   stored_events: 1500,
#   webhook_count: 1,
#   callback_count: 2
# }
```

## Testing

The system is designed for testability with mock injection:

```elixir
# Custom log fetcher for testing
defmodule MockFetcher do
  def fetch_logs(_subscription, _from_block) do
    {:ok, [%{"address" => "0x...", "topics" => [...], ...}], 18_000_100}
  end
end

{:ok, _} = Lux.EventMonitor.start_link(log_fetcher: MockFetcher)
```
