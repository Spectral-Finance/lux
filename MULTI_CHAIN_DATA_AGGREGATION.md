# Multi-Chain Data Aggregation Engine

A comprehensive multi-chain data aggregation system for collecting and processing blockchain data across multiple EVM-compatible networks. Built as a Lux framework module.

## Features

### ✅ Implemented

- **Multi-chain RPC Management**
  - Automatic failover between multiple RPC endpoints
  - Health checking and endpoint rotation
  - Rate limiting to prevent API abuse
  - Support for 7 major EVM chains

- **Real-time Block Monitoring**
  - Continuous block polling with chain-specific intervals
  - Transaction extraction and storage
  - Block reorganization detection
  - Real-time block notifications via PubSub

- **Smart Contract Event Aggregation**
  - Event log fetching with configurable filters
  - Event indexing for efficient querying
  - Real-time event streaming
  - Topic-based event filtering

- **Efficient Data Storage**
  - In-memory ETS tables for fast access
  - Indexed queries for blocks, transactions, and events
  - Configurable data retention policies
  - Automatic cleanup of expired data

- **Data Normalization**
  - Chain-specific field normalization
  - Timestamp standardization (Unix → ISO 8601)
  - Value conversion (wei → ether/gwei)
  - Address checksumming
  - Unified block/transaction/event formats

- **Query Interface**
  - Block queries with range filtering
  - Transaction queries by address/block
  - Event queries with topic filtering
  - Chain statistics

## Supported Chains

| Chain | Chain ID | Symbol | Poll Interval |
|-------|----------|--------|---------------|
| Ethereum Mainnet | 1 | ETH | 12s |
| Polygon Mainnet | 137 | MATIC | 2s |
| BNB Smart Chain | 56 | BNB | 3s |
| Arbitrum One | 42161 | ETH | 0.5s |
| Optimism | 10 | ETH | 2s |
| Avalanche C-Chain | 43114 | AVAX | 2s |
| Fantom Opera | 250 | FTM | 1s |

## Installation

Add to your `mix.exs`:

```elixir
def deps do
  [
    {:lux, "~> 0.5.0"}
  ]
end
```

## Usage

### Start the Aggregation Engine

```elixir
# Start with default chains
{:ok, pid} = Lux.DataAggregation.start_link()

# Start with specific chains
{:ok, pid} = Lux.DataAggregation.start_link(
  chains: [:ethereum, :polygon, :bsc]
)
```

### Query Blocks

```elixir
# Get recent blocks
blocks = Lux.DataAggregation.query_blocks(:ethereum)

# Get blocks in a range
blocks = Lux.DataAggregation.query_blocks(:ethereum,
  from: 19_000_000,
  to: 19_000_100,
  limit: 50
)
```

### Query Transactions

```elixir
# Get transactions for a block
txs = Lux.DataAggregation.query_transactions(:ethereum,
  block_number: 19_000_000
)

# Get transactions from an address
txs = Lux.DataAggregation.query_transactions(:ethereum,
  from: "0x..."
)
```

### Query Events

```elixir
# Get events for a contract
events = Lux.DataAggregation.query_events(:ethereum,
  "0xContractAddress",
  from_block: 19_000_000,
  limit: 100
)
```

### Real-time Subscriptions

```elixir
# Subscribe to block updates
Lux.DataAggregation.subscribe_blocks(:ethereum, self())

# Subscribe to contract events
Lux.DataAggregation.subscribe_events(:ethereum, "0xContractAddress", self())

# Handle messages
receive do
  %{type: :block, chain: :ethereum, block_number: num} ->
    IO.puts("New block: #{num}")

  %{type: :event, contract_address: addr, event: event} ->
    IO.puts("New event from: #{addr}")
end
```

### Register Contract Monitoring

```elixir
# Monitor a contract's events
Lux.DataAggregation.EventAggregator.register_contract(
  :ethereum,
  "0xContractAddress",
  abi,  # optional ABI for decoding
  topics  # optional topic filter
)
```

### Data Normalization

```elixir
# Normalize block data
normalized = Lux.DataAggregation.normalize(block_data, :ethereum)

# Normalize transaction
normalized = Lux.DataAggregation.normalize(tx_data, :polygon)

# Get chain stats
stats = Lux.DataAggregation.chain_stats(:ethereum)
```

## Architecture

```
Lux.DataAggregation (Supervisor)
├── RPCManager      - Multi-chain RPC connections with failover
├── DataStore       - ETS-based storage with indexing
├── Streamer        - PubSub-based real-time notifications
├── BlockMonitor    - Continuous block polling and processing
└── EventAggregator - Contract event monitoring and indexing
```

## RPC Failover

The RPCManager automatically handles endpoint failures:

1. Maintains multiple RPC endpoints per chain
2. Health checks every 60 seconds
3. Rotates to next healthy endpoint on failure
4. Tracks latency and failure counts
5. Maximum 3 retries before reporting error

## Rate Limiting

Built-in rate limiting prevents API abuse:
- Default: 10 requests/second per chain
- Configurable per-chain limits
- Automatic backoff on rate limit errors

## Data Retention

- Default retention: 24 hours
- Configurable via `retention_hours` option
- Automatic hourly cleanup
- ETS-based in-memory storage

## Testing

```bash
cd lux
mix test test/lux/data_aggregation_test.exs
```

## Acceptance Criteria

- [x] Support for major EVM chains (Ethereum, BSC, Polygon, Arbitrum, Optimism, Avalanche, Fantom)
- [x] Real-time block and transaction monitoring
- [x] Smart contract event filtering and processing
- [x] Efficient data storage and retrieval system
- [x] Query interface for aggregated data
- [x] Rate limiting and error handling
- [x] Documentation and examples
- [x] Integration tests demonstrating multi-chain

## License

MIT License - See LICENSE file for details.
