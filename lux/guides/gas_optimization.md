# Gas Optimization and Transaction Management

## Overview

A gas optimization system for cost-effective, reliable transaction execution with 3-tier pricing, transaction batching, speed-up/cancel, and cost analysis.

## Quick Start

### Gas Price Estimation

```elixir
alias Lux.Integrations.Web3.Gas.Estimator

{:ok, prices} = Estimator.estimate(rpc_url: "https://eth.llamarpc.com")
# => %{
#   slow: %{max_fee_per_gas: 25.5, max_priority_fee: 0.8, estimated_time: "~5 min"},
#   standard: %{max_fee_per_gas: 32.0, max_priority_fee: 1.0, estimated_time: "~1 min"},
#   fast: %{max_fee_per_gas: 45.0, max_priority_fee: 1.5, estimated_time: "~15 sec"},
#   base_fee_gwei: 28.0,
#   gas_price_gwei: 30.0
# }
```

### Gas Estimation for Transactions

```elixir
{:ok, estimate} = Estimator.estimate_gas(
  %{from: "0xsender", to: "0xreceiver", value: 1_000_000_000_000_000_000},
  rpc_url: "https://eth.llamarpc.com"
)
# => %{gas_estimate: 21000, gas_with_buffer: 25200}
```

### Cost Calculator

```elixir
# Without USD price
result = Estimator.calculate_cost(21_000, 30.0)
# => %{gas_limit: 21000, gas_price_gwei: 30.0, cost_eth: 0.00063}

# With USD price
result = Estimator.calculate_cost(21_000, 30.0, 2500.0)
# => %{..., cost_usd: 1.575}
```

### Transaction Manager

```elixir
alias Lux.Integrations.Web3.Gas.TransactionManager

{:ok, pid} = TransactionManager.start_link()

# Submit a transaction
{:ok, %{id: tx_id}} = TransactionManager.submit(pid, %{
  to: "0xreceiver",
  value: 1_000_000_000_000_000_000,
  gas_price: 30
})

# Speed up (bump gas 1.5x)
{:ok, result} = TransactionManager.speed_up(pid, tx_id, 1.5)
# => %{new_gas_price: 45, speed_ups: 1}

# Cancel a pending transaction
{:ok, %{status: :cancelled}} = TransactionManager.cancel(pid, tx_id)

# Batch multiple transactions
{:ok, batch} = TransactionManager.batch(pid, [
  %{to: "0xa", value: 100},
  %{to: "0xb", value: 200},
  %{to: "0xc", value: 300}
])
# => %{batch_ids: ["abc", "def", "ghi"], count: 3}
```

### Using the Prism Interface

```elixir
alias Lux.Prisms.Web3.Gas.OptimizeTransaction

# Submit
{:ok, _} = OptimizeTransaction.handler(%{action: "submit", tx: %{to: "0x...", value: 100}}, [])

# Speed up
{:ok, _} = OptimizeTransaction.handler(%{action: "speed_up", tx_id: id, gas_multiplier: 2.0}, [])

# Cancel
{:ok, _} = OptimizeTransaction.handler(%{action: "cancel", tx_id: id}, [])

# Batch
{:ok, _} = OptimizeTransaction.handler(%{action: "batch", transactions: [...]}, [])

# Simulate gas usage
{:ok, _} = OptimizeTransaction.handler(%{
  action: "simulate", tx: %{to: "0x...", data: "0x..."},
  rpc_url: "https://eth.llamarpc.com"
}, [])

# Cost analysis
{:ok, cost} = OptimizeTransaction.handler(%{
  action: "cost", gas_limit: 200_000, gas_price_gwei: 30.0, eth_price_usd: 2500.0
}, [])
```

### Gas Price Lens

```elixir
alias Lux.Lenses.Web3.Gas.GetGasPrice

{:ok, prices} = GetGasPrice.focus(%{rpc_url: "https://eth.llamarpc.com"})
```

## Gas Optimization Strategies

1. **Timing** — Use `slow` tier during off-peak (weekends, late night UTC)
2. **Batching** — Combine multiple transfers into one batch
3. **Priority fee** — Set just above median for inclusion without overpaying
4. **Speed up** — If stuck, bump gas by 1.5x instead of cancelling + resending
5. **MEV protection** — Priority fee optimization reduces MEV extraction risk

## Architecture

```
Estimator
├── 3-tier pricing (slow/standard/fast)
├── EIP-1559 base fee + priority fee
├── eth_estimateGas with 20% buffer
└── Cost calculator (ETH + USD)

TransactionManager (GenServer)
├── Submit with tracking
├── Speed up (gas bumping)
├── Cancel (status update)
├── Batch transactions
└── Status monitoring

Lenses: GetGasPrice
Prisms: OptimizeTransaction (6 actions)
```
