# Smart Contract Event Monitoring System Guide

## Overview

The **Smart Contract Event Monitoring System** (#75) provides an enterprise-grade infrastructure within the Lux framework for tracking, decoding, filtering, and dispatching smart contract events across heterogeneous EVM blockchains.

### Key Capabilities

- **Cross-Chain Subscriptions**: Monitor contracts on Ethereum, BSC, Polygon, Arbitrum, Optimism, Base, and Avalanche.
- **Out-of-the-Box Decoders**: Automatic ABI decoding for ERC-20, ERC-721, Uniswap V2/V3, WETH, and custom user-provided signatures.
- **Rule & Pattern Matching Engine**: Filter by topic hashes, indexed and unindexed parameters, value thresholds (`min_value`, `max_value`), and address whitelists/blacklists.
- **Historical Backfilling**: Chunked batch sync (`Syncer`) honoring RPC limits with automatic retry backoff.
- **Cryptographic Webhook Alerts**: Real-time notifications signed with HMAC-SHA256 (`X-Lux-Signature: sha256=<hex>`).
- **In-Memory Store & Replay**: Ring-buffer event indexing with deterministic historical replay.
- **AI Agent Prism**: Direct integration for autonomous agents via `Lux.Prisms.ContractEventMonitorPrism`.

---

## Architecture

```
                    ┌────────────────────────────────────────────────────────┐
                    │                   EVM Blockchains                      │
                    │   (Ethereum, BSC, Polygon, Arbitrum, Optimism, Base)   │
                    └───────────────────────────┬────────────────────────────┘
                                                │
                                    JSON-RPC eth_getLogs
                                                ▼
┌────────────────────────────────────────────────────────────────────────────────────────────┐
│                             Lux.Web3.EventMonitor Pipeline                                 │
│                                                                                            │
│   ┌───────────────────────────┐                ┌───────────────────────────────────────┐   │
│   │   SubscriptionManager     │                │                Decoder                │   │
│   │   (Registry & Status)     │                │   (Standard & Custom ABI Parsing)     │   │
│   └─────────────┬─────────────┘                └───────────────────┬───────────────────┘   │
│                 │                                                  │                       │
│                 ▼                                                  ▼                       │
│   ┌────────────────────────────────────────────────────────────────────────────────────┐   │
│   │                                   FilterEngine                                     │   │
│   │            (Topics, Value Thresholds, Whitelists, Parameter Predicates)            │   │
│   └─────────────────────────────────────┬──────────────────────────────────────────────┘   │
│                                         │                                                  │
│                                         ▼                                                  │
│   ┌───────────────────────────┐                ┌───────────────────────────────────────┐   │
│   │        EventStore         │                │           WebhookDispatcher           │   │
│   │   (Storage & Replay)      │                │        (HMAC-SHA256 & Retries)        │   │
│   └───────────────────────────┘                └───────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────────────────────────────┘
                                                ▲
                                                │
                                ┌───────────────┴───────────────┐
                                │   ContractEventMonitorPrism   │
                                │      (Lux AI Agent Tool)      │
                                └───────────────────────────────┘
```

---

## 1. Creating a Contract Subscription

To subscribe to events on a specific contract (e.g. USDT transfers on Ethereum with values $\ge 10,000$ USDT):

```elixir
{:ok, subscription} = Lux.Web3.EventMonitor.subscribe(%{
  name: "Whale USDT Transfers",
  chain: :ethereum,
  chain_id: 1,
  contract_address: "0xdac17f958d2ee523a2206206994597c13d831ec7",
  event_name: "Transfer",
  event_signature: "Transfer(address,address,uint256)",
  webhook_url: "https://api.myprotocol.com/webhooks/usdt",
  webhook_secret: "my_hmac_secret_key_123",
  filter_pattern: %{
    min_value: 10_000_000_000 # 10,000 USDT (6 decimals)
  }
})
```

---

## 2. Ingesting Real-Time Logs

When logs are received from JSON-RPC or WebSocket block subscriptions:

```elixir
raw_log = %{
  "address" => "0xdac17f958d2ee523a2206206994597c13d831ec7",
  "topics" => [
    "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
    "0x0000000000000000000000001111111111111111111111111111111111111111",
    "0x0000000000000000000000002222222222222222222222222222222222222222"
  ],
  "data" => "0x00000000000000000000000000000000000000000000000000000002540be400",
  "blockNumber" => "0x12a3b4",
  "transactionHash" => "0x9876543210abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
  "logIndex" => "0x01"
}

{:ok, processed_events} = Lux.Web3.EventMonitor.ingest_log(raw_log, :ethereum, 1)
```

---

## 3. Webhook Authentication (HMAC-SHA256)

Every webhook payload dispatched to `webhook_url` includes the `X-Lux-Signature` header:

```http
POST /webhooks/usdt HTTP/1.1
Host: api.myprotocol.com
Content-Type: application/json
X-Lux-Signature: sha256=a1b2c3d4e5f6...

{
  "event_id": "evt_1_98765432..._1_sub_123",
  "subscription_id": "sub_123",
  "chain": "ethereum",
  "chain_id": 1,
  "contract_address": "0xdac17f958d2ee523a2206206994597c13d831ec7",
  "event_name": "transfer",
  "block_number": 1221556,
  "tx_hash": "0x98765432...",
  "decoded_params": {
    "from": "0x1111111111111111111111111111111111111111",
    "to": "0x2222222222222222222222222222222222222222",
    "value": 10000000000
  },
  "timestamp": 1729000000
}
```

Verify in Elixir / Node:
```elixir
expected_signature = :crypto.mac(:hmac, :sha256, secret, raw_body) |> Base.encode16(case: :lower)
Plug.Crypto.secure_compare(expected_signature, header_signature)
```

---

## 4. Historical Event Syncing

To backfill events from block 18,000,000 to block 18,010,000:

```elixir
{:ok, report} = Lux.Web3.EventMonitor.sync_historical(
  subscription.id,
  18_000_000,
  18_010_000,
  chunk_size: 2_000
)

IO.inspect(report)
# => %{blocks_scanned: 10_001, chunks: 6, events_found: 42}
```

---

## 5. Event Replay Engine

Replay historical events through filters and notification webhooks:

```elixir
# Replay all events stored for a subscription
{:ok, count} = Lux.Web3.EventMonitor.replay(%{subscription_id: subscription.id}, fn event ->
  IO.puts("Replayed event: #{event.id} at block #{event.block_number}")
end)
```

---

## 6. AI Agent Integration via Prism

Lux AI Agents can control the monitoring system directly using `ContractEventMonitorPrism`:

```elixir
{:ok, result} = Lux.Prisms.ContractEventMonitorPrism.run(%{
  "action" => "subscribe",
  "chain" => "polygon",
  "chain_id" => 137,
  "contract_address" => "0x2791bca1f2de4661ed88a30c99a7a9449aa84174",
  "event_name" => "Transfer",
  "webhook_url" => "https://agent.local/notify",
  "filter_pattern" => %{"min_value" => 50_000_000_000}
})
```
