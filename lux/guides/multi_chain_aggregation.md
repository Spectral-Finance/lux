# Multi-Chain Data Aggregation Engine

The Multi-Chain Data Aggregation Engine provides a unified interface for collecting, normalizing, and querying blockchain data across multiple EVM-compatible networks simultaneously.

## Overview

Modern DeFi and Web3 applications often need to interact with multiple blockchains. The Multi-Chain engine abstracts away the complexity of managing multiple RPC connections, normalizing data formats, and handling chain-specific quirks.

### Supported Chains

| Chain | Chain ID | Native Currency | Block Time |
|-------|----------|----------------|------------|
| Ethereum | 1 | ETH | ~12s |
| Polygon | 137 | MATIC | ~2s |
| BNB Smart Chain | 56 | BNB | ~3s |
| Arbitrum One | 42161 | ETH | ~250ms |
| Optimism | 10 | ETH | ~2s |
| Base | 8453 | ETH | ~2s |
| Avalanche C-Chain | 43114 | AVAX | ~2s |

## Architecture

The engine is composed of several layers:

```
┌─────────────────────────────────────────────┐
│            Prisms & Lenses                   │
│  (CrossChainBalance, GasComparison, etc.)    │
├─────────────────────────────────────────────┤
│              Aggregator                      │
│  (Parallel queries, cross-chain logic)       │
├─────────────────────────────────────────────┤
│          Normalizer + DataModel              │
│  (Unified structs, data transformation)      │
├────────────────────┬────────────────────────┤
│   RPC Manager      │       Cache             │
│  (Rate limiting,   │  (ETS-based TTL cache)  │
│   retries, health) │                         │
├────────────────────┴────────────────────────┤
│              Chain Registry                  │
│  (Chain configs, endpoints, metadata)        │
└─────────────────────────────────────────────┘
```

### Components

- **`Lux.Chain`** — Chain registry with metadata for all supported networks
- **`Lux.MultiChain.DataModel`** — Unified data structs (Block, Transaction, Event, TokenBalance, GasPrice)
- **`Lux.MultiChain.Normalizer`** — Transforms raw API/RPC responses into DataModel structs
- **`Lux.MultiChain.Cache`** — ETS-based TTL cache to reduce redundant API calls
- **`Lux.MultiChain.RpcManager`** — JSON-RPC client with rate limiting and retry logic
- **`Lux.MultiChain.Aggregator`** — Core engine for parallel cross-chain queries

## Quick Start

### Configuration

Configure RPC endpoints in your application config:

```elixir
# config/config.exs
config :lux, :multi_chain,
  rpc_endpoints: %{
    ethereum: ["https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY"],
    polygon: ["https://polygon-mainnet.g.alchemy.com/v2/YOUR_KEY"],
    bsc: ["https://bsc-dataseed.binance.org"],
    arbitrum: ["https://arb1.arbitrum.io/rpc"],
    optimism: ["https://mainnet.optimism.io"],
    base: ["https://mainnet.base.org"],
    avalanche: ["https://api.avax.network/ext/bc/C/rpc"]
  }
```

> **Note:** If no endpoints are configured, the engine falls back to public RPC endpoints. For production use, always configure dedicated endpoints.

### Basic Usage

#### Check Balances Across Chains

```elixir
# Using the Aggregator directly
{:ok, balances} = Lux.MultiChain.Aggregator.get_balances(
  "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
  [:ethereum, :polygon, :bsc]
)

for balance <- balances do
  IO.puts("#{balance.chain}: #{balance.balance_formatted} #{balance.token_symbol}")
end
# ethereum: 1.5 ETH
# polygon: 100.0 MATIC
# bsc: 0.5 BNB
```

#### Using the Prism

```elixir
{:ok, result} = Lux.Prisms.MultiChain.CrossChainBalancePrism.run(%{
  address: "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
  chains: ["ethereum", "polygon", "bsc"]
})

IO.inspect(result.balances)
```

#### Compare Gas Prices

```elixir
{:ok, result} = Lux.Prisms.MultiChain.GasComparisonPrism.run(%{
  chains: ["ethereum", "polygon", "bsc", "arbitrum"]
})

IO.puts("Cheapest chain: #{result.cheapest_chain}")
IO.puts("Most expensive: #{result.most_expensive_chain}")

for price <- result.gas_prices do
  IO.puts("#{price.chain}: #{price.standard_gwei} gwei")
end
```

#### Get Chain Summary

```elixir
{:ok, result} = Lux.Prisms.MultiChain.ChainSummaryPrism.run(%{
  chains: ["ethereum", "polygon", "bsc"],
  address: "0x742d..."  # optional
})

for summary <- result.summaries do
  IO.puts("#{summary.chain}: block #{summary.latest_block}, gas #{summary.gas_price_gwei} gwei")
end
```

#### Look Up Transactions

```elixir
# Search across chains when origin unknown
{:ok, result} = Lux.Prisms.MultiChain.TransactionLookupPrism.run(%{
  tx_hash: "0xabc...",
  chains: ["ethereum", "polygon", "bsc"]
})

IO.puts("Found on: #{result.found_on}")
IO.inspect(result.transaction)
```

#### Monitor Events/Logs

```elixir
{:ok, events} = Lux.MultiChain.Aggregator.get_events(:ethereum, %{
  address: "0xdAC17F958D2ee523a2206206994597C13D831ec7",  # USDT
  topics: ["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"],  # Transfer
  from_block: 18_000_000,
  to_block: 18_000_100
})

for event <- events do
  IO.puts("Transfer at block #{event.block_number}")
end
```

## Using Lenses

The multi-chain lenses provide direct access to Etherscan v2 API with chain routing:

```elixir
# Balance across chains
{:ok, result} = Lux.Lenses.MultiChain.BalanceLens.focus(%{
  address: "0x742d...",
  chainid: 137  # Polygon
})

# Gas prices
{:ok, result} = Lux.Lenses.MultiChain.GasLens.focus(%{chainid: 1})

# Transaction list
{:ok, result} = Lux.Lenses.MultiChain.TransactionLens.focus(%{
  address: "0x742d...",
  chainid: 56,  # BSC
  startblock: 30_000_000
})

# Event logs
{:ok, result} = Lux.Lenses.MultiChain.EventLogLens.focus(%{
  address: "0xdAC17F958D2ee523a2206206994597C13D831ec7",
  chainid: 1,
  topic0: "0xddf252ad..."
})
```

## Caching

The engine includes an ETS-based cache to minimize redundant API calls:

```elixir
# Cache is initialized automatically
# TTLs are set per data type:
# - Block data: chain block time (12s for Ethereum, 2s for Polygon)
# - Gas prices: chain block time
# - Balances: 15 seconds
# - Transactions: 5 minutes (immutable once confirmed)

# Manual cache management
Lux.MultiChain.Cache.clear_chain(:ethereum)
Lux.MultiChain.Cache.clear_all()
Lux.MultiChain.Cache.cleanup_expired()
```

## Data Models

All data is normalized into consistent structs:

### Block
```elixir
%Lux.MultiChain.DataModel.Block{
  chain: :ethereum,
  chain_id: 1,
  number: 18_000_000,
  hash: "0x...",
  timestamp: ~U[2023-09-01 00:00:00Z],
  gas_used: 15_000_000,
  transaction_count: 150
}
```

### Transaction
```elixir
%Lux.MultiChain.DataModel.Transaction{
  chain: :polygon,
  hash: "0x...",
  from: "0xsender",
  to: "0xreceiver",
  value_decimal: 1.5,
  status: :success
}
```

### Event
```elixir
%Lux.MultiChain.DataModel.Event{
  chain: :ethereum,
  address: "0xcontract",
  topics: ["0xtopic0", ...],
  event_name: "Transfer",
  block_number: 18_000_000
}
```

### TokenBalance
```elixir
%Lux.MultiChain.DataModel.TokenBalance{
  chain: :ethereum,
  address: "0xholder",
  token_symbol: "ETH",
  balance_formatted: 1.5,
  token_type: :native
}
```

### GasPrice
```elixir
%Lux.MultiChain.DataModel.GasPrice{
  chain: :ethereum,
  safe_gas_price: 20.0,
  propose_gas_price: 25.0,
  fast_gas_price: 35.0,
  unit: "gwei"
}
```

## Error Handling

The engine uses partial success semantics — if some chains fail, results from successful chains are still returned:

```elixir
{:ok, balances} = Aggregator.get_balances("0x...", [:ethereum, :polygon, :bad_chain])
# Returns balances for ethereum and polygon, ignoring bad_chain
```

Rate limiting errors trigger automatic retry with exponential backoff (up to 3 attempts).

## Integration with Agents

The multi-chain prisms are designed to work seamlessly with Lux agents:

```elixir
defmodule MyAgent do
  use Lux.Agent,
    name: "Portfolio Tracker",
    prisms: [
      Lux.Prisms.MultiChain.CrossChainBalancePrism,
      Lux.Prisms.MultiChain.GasComparisonPrism,
      Lux.Prisms.MultiChain.ChainSummaryPrism,
      Lux.Prisms.MultiChain.TransactionLookupPrism
    ]

  # The agent can now use these prisms to analyze
  # cross-chain portfolio data, compare gas costs,
  # and track transactions across networks.
end
```
