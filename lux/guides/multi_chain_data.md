# Multi-Chain Data Aggregation

## Overview

Lux provides a comprehensive multi-chain data aggregation engine for collecting and processing blockchain data across 7 EVM-compatible networks simultaneously.

## Supported Chains

| Chain | ID | Symbol | Explorer |
|-------|------|--------|----------|
| Ethereum | 1 | ETH | etherscan.io |
| Polygon | 137 | MATIC | polygonscan.com |
| Arbitrum | 42161 | ETH | arbiscan.io |
| Optimism | 10 | ETH | optimistic.etherscan.io |
| Base | 8453 | ETH | basescan.org |
| BSC | 56 | BNB | bscscan.com |
| Avalanche | 43114 | AVAX | snowtrace.io |

## Quick Start

### RPC Manager

The `RpcManager` handles multi-chain RPC connections with health tracking, load balancing, and automatic failover.

```elixir
# Start the manager
{:ok, pid} = Lux.Integrations.Web3.Chain.RpcManager.start_link()

# Get RPC URL for a chain
{:ok, url} = RpcManager.get_rpc(pid, :ethereum)

# Check chain info
{:ok, info} = RpcManager.chain_info(pid, :polygon)
# => %{chain_id: 137, symbol: "MATIC", rpcs: [...]}

# View RPC health
health = RpcManager.health(pid)
```

### Block Monitoring

Real-time block monitoring with pub/sub notifications:

```elixir
{:ok, monitor} = Lux.Integrations.Web3.Chain.BlockMonitor.start_link(
  chain: :ethereum,
  rpc_url: "https://eth.llamarpc.com",
  poll_interval_ms: 12_000
)

# Subscribe to new blocks
BlockMonitor.subscribe(monitor, self())

# Receive notifications
receive do
  {:new_block, :ethereum, block_number} ->
    IO.puts("New block: #{block_number}")
end
```

### Fetching Block Data

```elixir
alias Lux.Lenses.Web3.Chain.GetBlock

# Latest block
{:ok, block} = GetBlock.focus(%{rpc_url: url})
# => %{number: 19000000, hash: "0x...", transaction_count: 150, gas_used: ...}

# Specific block
{:ok, block} = GetBlock.focus(%{rpc_url: url, block: 19000000})
```

### Transaction Details

```elixir
alias Lux.Lenses.Web3.Chain.GetTransaction

# Transaction details
{:ok, tx} = GetTransaction.focus(%{rpc_url: url, tx_hash: "0x..."})

# Receipt with logs
{:ok, receipt} = GetTransaction.focus(%{rpc_url: url, tx_hash: "0x...", action: "receipt"})

# Both together
{:ok, full} = GetTransaction.focus(%{rpc_url: url, tx_hash: "0x...", action: "both"})
```

### Event Logs

```elixir
alias Lux.Lenses.Web3.Chain.GetLogs

{:ok, result} = GetLogs.focus(%{
  rpc_url: url,
  address: "0xdAC17F958D2ee523a2206206994597C13D831ec7",
  from_block: 19000000,
  to_block: "latest",
  topics: ["0xddf252ad..."]  # Transfer events
})
# => %{logs: [...], count: 42}
```

### Cross-Chain Queries

```elixir
alias Lux.Prisms.Web3.Chain.MultiChainQuery

# Check balance across all chains
{:ok, result} = MultiChainQuery.handler(%{
  action: "multi_balance",
  address: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
  chains: ["ethereum", "polygon", "base"]
}, [])
# => %{balances: [%{chain: :ethereum, balance: 1.5, symbol: "ETH"}, ...]}

# Compare chains (block height, gas prices)
{:ok, result} = MultiChainQuery.handler(%{
  action: "chain_compare",
  chains: ["ethereum", "polygon", "arbitrum"]
}, [])
```

## Architecture

```
RpcManager (GenServer)
├── Health tracking per endpoint
├── Load balancing (prefer healthy RPCs)
└── Automatic failover

RpcClient
├── JSON-RPC 2.0 client
├── Retry on 429/5xx
└── Batch request support

BlockMonitor (GenServer)
├── Configurable poll interval
├── Pub/sub notifications
└── Auto-cleanup on subscriber exit

Lenses: GetBlock, GetTransaction, GetLogs
Prisms: MultiChainQuery
```

## Error Handling

All modules handle RPC errors gracefully:
- Connection failures → automatic retry with backoff
- Rate limiting (429) → retry with delay
- Invalid responses → `{:error, reason}` tuples
- Health tracking → unhealthy RPCs deprioritized
