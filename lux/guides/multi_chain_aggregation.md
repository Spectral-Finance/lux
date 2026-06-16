# Multi-Chain Data Aggregation Engine

This bounty implementation adds `Lux.Web3.MultiChain.Aggregator` and `Lux.Prisms.Web3.AggregateMultiChainData`.

## Capabilities

- Supports major EVM chain definitions: Ethereum, Base, Arbitrum, Optimism, Polygon, and BSC.
- Normalizes block, transaction, and contract event records across chains.
- Tracks latest block per chain and transaction/event counts.
- Provides event query filters by chain, address, event name, and minimum block.
- Builds JSON-RPC polling plans for `eth_blockNumber` and `eth_getLogs`.
- Provides retention filtering and stream-ready snapshot summaries.

The core module is storage-neutral. Callers can feed records from live RPC workers, indexers, data warehouses, or tests.
