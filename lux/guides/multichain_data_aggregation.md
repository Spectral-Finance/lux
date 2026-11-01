# Multi-Chain Data Aggregation Engine Guide (#74)

The **Multi-Chain Data Aggregation Engine** provides real-time ingestion, normalization, indexing, querying, and streaming for EVM-compatible blockchains within the Lux framework.

---

## 1. Supported EVM Networks

The engine provides out-of-the-box support and automated RPC management for major networks:

| Chain Identifier | Network Name | Chain ID | Default Primary RPC |
|---|---|:---:|---|
| `:ethereum` | Ethereum Mainnet | 1 | `https://eth.llamarpc.com` |
| `:bsc` | BNB Smart Chain | 56 | `https://binance.llamarpc.com` |
| `:polygon` | Polygon PoS | 137 | `https://polygon.llamarpc.com` |
| `:arbitrum` | Arbitrum One | 42161 | `https://arbitrum.llamarpc.com` |
| `:optimism` | OP Mainnet | 10 | `https://optimism.llamarpc.com` |
| `:base` | Base | 8453 | `https://base.llamarpc.com` |
| `:avalanche` | Avalanche C-Chain | 43114 | `https://api.avax.network/ext/bc/C/rpc` |

---

## 2. Core Architecture

```
                       +-----------------------------+
                       |       EVM Networks          |
                       | (ETH, BSC, MATIC, ARB, etc) |
                       +--------------+--------------+
                                      |
                                      v
                       +-----------------------------+
                       |        RpcManager           |
                       |  - Endpoint failover        |
                       |  - Rate limit backoff       |
                       |  - Health checks            |
                       +--------------+--------------+
                                      |
                                      v
                       +-----------------------------+
                       |    Normalization Layer      |
                       |  - Schemas.Block            |
                       |  - Schemas.Transaction      |
                       |  - Schemas.Event            |
                       |  - Schemas.TokenTransfer    |
                       +--------------+--------------+
                                      |
                                      v
                       +-----------------------------+
                       |       Aggregator Engine     |
                       |  - Multi-chain in-memory DB |
                       |  - Retention policy pruning |
                       |  - Real-time PubSub stream  |
                       |  - Query interface         |
                       +--------------+--------------+
                                      |
                 +--------------------+--------------------+
                 |                                         |
                 v                                         v
   +---------------------------+             +---------------------------+
   |   PubSub Subscribers      |             |     Lux AI Prisms         |
   | (GenServers, WebSockets)  |             | (MultichainQueryPrism)    |
   +---------------------------+             +---------------------------+
```

---

## 3. Usage Examples

### Querying Normalized Blocks Across Chains
```elixir
# Query latest 10 blocks on Arbitrum
blocks = Lux.Web3.Multichain.query_blocks(%{
  chain: :arbitrum,
  limit: 10
})

# Filter blocks by number range
blocks = Lux.Web3.Multichain.query_blocks(%{
  chain: :ethereum,
  from_block: 19_000_000,
  to_block: 19_000_100
})
```

### Subscribing to Real-Time Blockchain Events
```elixir
# Subscribe current process to all Ethereum USDC transfer events
Lux.Web3.Multichain.subscribe({:events, :ethereum, "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"})

# Receive stream message in GenServer handle_info
def handle_info({:new_event, :ethereum, %Lux.Web3.Multichain.Schemas.Event{} = event}, state) do
  IO.inspect(event.decoded_params, label: "New USDC Transfer")
  {:noreply, state}
end
```

### Ingesting Raw JSON-RPC Data
```elixir
# Ingest raw block payload from eth_getBlockByNumber
{:ok, block} = Lux.Web3.Multichain.ingest_block(:base, raw_json_rpc_block)
```

---

## 4. Retention & Storage Policies

The engine enforces configurable retention to prevent unbounded memory growth in production:
- `max_blocks_per_chain`: Max number of recent blocks kept per chain (default: 1,000 blocks).
- `retention_ttl_sec`: Time-to-live for historical records in seconds (default: 86,400s / 24h).
- Automatic pruning runs upon block ingestion or manually via `Lux.Web3.Multichain.Aggregator.prune/1`.
