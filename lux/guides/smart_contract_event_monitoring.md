# Smart Contract Event Monitoring

Lux exposes a transport-neutral event monitoring core under `Lux.Web3.EventMonitor`.
RPC and WebSocket adapters can use the same subscription, matching, persistence,
replay, and webhook notification primitives.

## Define a Subscription

```elixir
{:ok, subscription} =
  Lux.Web3.EventMonitor.subscription(
    id: "usdc-transfers",
    chain_id: 1,
    contract_address: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
    event_name: "Transfer",
    topics: [
      "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
    ],
    from_block: 20_000_000,
    to_block: :latest,
    webhook_url: "https://example.com/lux/events"
  )
```

Topic filters support exact topic matches, `nil` wildcards, or a list of accepted
topics for a single indexed position.

## Plan Historical Sync

```elixir
Lux.Web3.EventMonitor.historical_ranges(subscription, 20_005_500, 2_000)
```

This returns bounded `%{from_block: ..., to_block: ...}` ranges that an adapter can
pass to `eth_getLogs`.

## Ingest Logs

```elixir
{:ok, store} = Lux.Web3.EventMonitor.Store.start_link([])

{:ok, matched_events} =
  Lux.Web3.EventMonitor.ingest_log(raw_rpc_log, [subscription],
    chain_id: 1,
    store: store,
    webhook_secret: "shared-secret"
  )
```

`ingest_log/3` normalizes raw JSON-RPC logs, applies subscription filters, stores
matching events, and emits webhook notifications when a subscription has a
`webhook_url`.

## Replay Events

```elixir
Lux.Web3.EventMonitor.Store.replay(store, "usdc-transfers")
```

Events are deduplicated by `{chain_id, transaction_hash, log_index}` and replayed
in block/log order.
