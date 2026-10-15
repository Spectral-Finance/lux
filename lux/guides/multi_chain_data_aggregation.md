# Multi-Chain Data Aggregation Engine

Lux provides a Multi-Chain Data Aggregation Engine (`Lux.Web3.Aggregator`) for collecting, normalizing, indexing, streaming, and querying blockchain data across major EVM networks (`:ethereum`, `:bsc`, `:polygon`, `:arbitrum`, `:optimism`, `:base`, and `:avalanche`).

## Architecture

- **`Lux.Web3.Aggregator`** — Top-level orchestrator for multi-chain block syncing, historical block indexing, smart contract event collection, and real-time process subscriptions
- **`Lux.Web3.Aggregator.RPCManager`** — Multi-endpoint JSON-RPC manager with per-chain rate limiting and automatic backup endpoint failover
- **`Lux.Web3.Aggregator.Normalizer`** — Normalizes heterogeneous EVM blocks, transactions, and event logs (`Transfer`, `Approval`, `Swap`) into `%NormalizedBlock{}`, `%NormalizedTransaction{}`, and `%NormalizedEvent{}`
- **`Lux.Web3.Aggregator.Store`** — ETS-indexed storage engine with query caching, pagination, cross-chain summary statistics, and configurable retention pruning
- **`Lux.Prisms.Web3.MultiChainAggregatorPrism`** — Agent tool Prism for multi-chain data collection and querying

## Usage Examples

```elixir
# 1. Subscribe to real-time normalized blocks and events
:ok = Lux.Web3.Aggregator.subscribe(self(), :all)

# 2. Sync latest blocks across Ethereum, BNB Smart Chain, Polygon, and Arbitrum
{:ok, %{blocks: blocks}} =
  Lux.Web3.Aggregator.sync_latest_blocks([:ethereum, :bsc, :polygon, :arbitrum])

# 3. Collect and decode smart contract events across chains
{:ok, %{events: events}} =
  Lux.Web3.Aggregator.collect_events([:ethereum, :polygon], %{
    contract_address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    from_block: 19_000_000,
    to_block: 19_000_100
  })

# 4. Query normalized events and enforce retention limits
transfers = Lux.Web3.Aggregator.query_events(event_name: "Transfer", limit: 50)
Lux.Web3.Aggregator.enforce_retention(max_blocks_per_chain: 1_000, max_events: 10_000)
```
