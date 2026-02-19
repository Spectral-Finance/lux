# Gas Optimization and Transaction Management

This guide covers the gas optimization and transaction management system in Lux,
designed to ensure cost-effective and reliable transaction execution on Ethereum
and EVM-compatible networks.

## Overview

The gas optimization system provides a comprehensive suite of tools for:

- **Gas Price Estimation** — Predict optimal gas prices across urgency levels
- **EIP-1559 Fee Calculation** — Calculate and predict EIP-1559 fee parameters
- **Transaction Batching** — Group transactions for gas-efficient execution
- **Transaction Replacement** — Speed up or cancel pending transactions
- **MEV Protection** — Detect and mitigate MEV attack vectors
- **Transaction Simulation** — Estimate gas and detect failures before submission
- **Cost Optimization** — Comprehensive strategies to minimize gas costs
- **Gas Usage Analytics** — Real-time network analytics and cost matrix

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                 Gas Optimization System              │
├─────────────────┬───────────────────────────────────┤
│     Prisms      │             Lenses                │
├─────────────────┼───────────────────────────────────┤
│ GasPriceEstim.  │ GasOracle (existing)              │
│ EIP1559FeeCal.  │ GasEstimate (existing)            │
│ TxBatcher       │ GasUsageAnalytics (new)           │
│ TxReplacer      │                                   │
│ MEVProtection   │                                   │
│ TxSimulator     │                                   │
│ CostOptimizer   │                                   │
└─────────────────┴───────────────────────────────────┘
```

## Quick Start

### Gas Price Estimation

Get optimal gas prices for different urgency levels:

```elixir
# Standard urgency (recommended for most transactions)
{:ok, estimate} = Lux.Prisms.GasOptimization.GasPriceEstimatorPrism.run(%{
  strategy: "standard",
  network: "mainnet"
})

# Returns both legacy and EIP-1559 fee parameters
IO.inspect(estimate.legacy.gas_price_gwei)           # e.g., 20.0
IO.inspect(estimate.eip1559.max_fee_per_gas_gwei)    # e.g., 30.0
IO.inspect(estimate.eip1559.base_fee_gwei)           # e.g., 18.5
IO.inspect(estimate.estimated_wait_seconds)           # e.g., 30
IO.inspect(estimate.confidence)                       # e.g., 0.85

# Fast execution for urgent transactions
{:ok, fast} = Lux.Prisms.GasOptimization.GasPriceEstimatorPrism.run(%{
  strategy: "fast",
  gas_limit: 150_000,
  max_fee_cap_gwei: 50.0  # Safety cap
})
```

### EIP-1559 Fee Calculation

Calculate optimal EIP-1559 parameters with base fee prediction:

```elixir
# Calculate fees for medium urgency
{:ok, fees} = Lux.Prisms.GasOptimization.EIP1559FeeCalculatorPrism.run(%{
  action: "calculate",
  urgency: "high"
})

IO.inspect(fees.max_fee_per_gas_gwei)          # Recommended maxFeePerGas
IO.inspect(fees.max_priority_fee_gwei)         # Recommended maxPriorityFeePerGas
IO.inspect(fees.fee_savings_vs_legacy_pct)     # Savings vs legacy pricing

# Predict future base fees
{:ok, predictions} = Lux.Prisms.GasOptimization.EIP1559FeeCalculatorPrism.run(%{
  action: "predict",
  prediction_blocks: 10,
  current_base_fee_gwei: 20.0,
  gas_used_ratios: "0.6,0.7,0.55,0.8"
})

IO.inspect(predictions.predicted_base_fees)    # Next 10 blocks
IO.inspect(predictions.trend)                  # "increasing", "decreasing", "stable"

# Bump fees for stuck transaction (speed up)
{:ok, bumped} = Lux.Prisms.GasOptimization.EIP1559FeeCalculatorPrism.run(%{
  action: "bump",
  original_max_fee_gwei: 20.0,
  original_priority_fee_gwei: 2.0
})
```

### Transaction Batching

Optimize gas by batching multiple transactions:

```elixir
{:ok, batches} = Lux.Prisms.GasOptimization.TransactionBatcherPrism.run(%{
  transactions: [
    %{id: "transfer_1", to: "0xabc...", gas_estimate: 65_000, priority: "high"},
    %{id: "transfer_2", to: "0xabc...", gas_estimate: 65_000, priority: "medium"},
    %{id: "approve",    to: "0xdef...", gas_estimate: 46_000, priority: "low"},
    %{id: "swap",       to: "0xghi...", gas_estimate: 150_000, priority: "medium",
     depends_on: ["approve"]}
  ],
  max_batch_gas: 300_000,
  strategy: "priority_first"  # or "gas_optimal", "same_target"
})

IO.inspect(batches.batch_count)                # Number of batches
IO.inspect(batches.total_gas_saved)            # Gas units saved
IO.inspect(batches.total_savings_pct)          # Percentage saved
```

### Transaction Replacement (Speed Up / Cancel)

Replace pending transactions:

```elixir
# Speed up a stuck transaction
{:ok, speedup} = Lux.Prisms.GasOptimization.TransactionReplacerPrism.run(%{
  action: "speed_up",
  original_tx: %{
    nonce: 42,
    to: "0xabc...",
    value: "1000000000000000000",
    max_fee_per_gas_gwei: 20.0,
    max_priority_fee_per_gas_gwei: 2.0,
    gas_limit: 21_000
  },
  from: "0x1234...",
  bump_percentage: 15.0   # 15% bump (minimum 10%)
})

# Cancel a pending transaction
{:ok, cancel} = Lux.Prisms.GasOptimization.TransactionReplacerPrism.run(%{
  action: "cancel",
  original_tx: %{nonce: 42, max_fee_per_gas_gwei: 20.0, max_priority_fee_per_gas_gwei: 2.0},
  from: "0x1234..."
})
# Creates a 0-value self-transfer with bumped fees
```

### MEV Protection

Analyze transactions for MEV vulnerabilities:

```elixir
{:ok, analysis} = Lux.Prisms.GasOptimization.MEVProtectionPrism.run(%{
  transaction: %{
    to: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",  # Uniswap V2
    data: "0x38ed1739...",
    type: "swap",
    slippage_tolerance: 1.0
  },
  value_eth: 5.0
})

IO.inspect(analysis.risk_level)                  # "high"
IO.inspect(analysis.mev_risks)                   # ["sandwich_attack", "frontrunning"]
IO.inspect(analysis.recommended_protections)     # Flashbots, slippage guard, etc.
IO.inspect(analysis.safe_submission_methods)      # ["flashbots_protect", ...]
IO.inspect(analysis.estimated_mev_exposure_eth)  # Estimated ETH at risk
```

### Transaction Simulation

Simulate transactions before submission:

```elixir
{:ok, sim} = Lux.Prisms.GasOptimization.TransactionSimulatorPrism.run(%{
  transactions: [
    %{
      from: "0x1234...",
      to: "0xabc...",
      data: "0xa9059cbb0000...",   # ERC20 transfer
      value: "0"
    },
    %{
      from: "0x1234...",
      to: "0xdef...",
      data: "0x38ed1739...",       # DEX swap
      value: "0"
    }
  ],
  gas_price_gwei: 25.0,
  include_trace: true
})

IO.inspect(sim.all_successful)    # true/false
IO.inspect(sim.total_gas)         # Total gas across all txs
IO.inspect(sim.total_cost_eth)    # Total cost in ETH

Enum.each(sim.simulations, fn s ->
  IO.puts("#{s.tx_type}: #{s.gas_used} gas, #{s.cost_eth} ETH - #{s.status}")
end)
```

### Cost Optimization

Get comprehensive cost optimization strategies:

```elixir
{:ok, optimized} = Lux.Prisms.GasOptimization.CostOptimizerPrism.run(%{
  transactions: [
    %{type: "erc20_approve", gas_estimate: 46_000, urgency: "medium"},
    %{type: "swap", gas_estimate: 150_000, urgency: "medium"},
    %{type: "erc20_transfer", gas_estimate: 65_000, urgency: "low"},
    %{type: "erc20_transfer", gas_estimate: 65_000, urgency: "low"}
  ],
  budget_eth: 0.01,
  optimization_level: "aggressive"
})

IO.inspect(optimized.total_estimated_cost_eth)   # Current cost
IO.inspect(optimized.potential_savings_eth)       # Possible savings
IO.inspect(optimized.within_budget)               # Budget check

# L2 alternatives with cost comparison
Enum.each(optimized.l2_alternatives, fn alt ->
  IO.puts("#{alt.network}: #{alt.estimated_cost_eth} ETH (#{alt.savings_pct}% savings)")
end)

# Optimization strategies
Enum.each(optimized.optimizations, fn opt ->
  IO.puts("[#{opt.strategy}] #{opt.description} — saves #{opt.estimated_savings_eth} ETH")
end)
```

### Gas Usage Analytics

Real-time network analytics via the GasUsageAnalytics lens:

```elixir
{:ok, %{analytics: data}} = Lux.Lenses.Etherscan.GasUsageAnalytics.focus(%{chainid: 1})

# Current prices
IO.inspect(data.current_prices)

# Network congestion
IO.puts("Congestion: #{data.network_status.congestion_level}")
IO.puts("Utilization: #{data.network_status.avg_utilization}%")

# Cost matrix for common operations
Enum.each(data.cost_matrix, fn op ->
  IO.puts("#{op.operation}: #{op.cost_standard_eth} ETH (standard)")
end)

# Recommendations
Enum.each(data.recommendations, &IO.puts/1)
```

## Strategies Overview

### Gas Pricing Strategies

| Strategy | Wait Time | Use Case |
|----------|-----------|----------|
| `slow`   | ~120s     | Non-urgent transfers, batch operations |
| `standard` | ~30s   | Regular transactions, most operations |
| `fast`   | ~15s      | Time-sensitive operations |
| `instant` | ~6s      | Critical/emergency transactions |

### Batching Strategies

| Strategy | Description |
|----------|-------------|
| `gas_optimal` | Maximize gas utilization per batch (default) |
| `priority_first` | Process highest-priority transactions first |
| `same_target` | Group transactions to same contract address |

### Cost Optimization Levels

| Level | Description |
|-------|-------------|
| `basic` | Timing and EIP-1559 suggestions only |
| `standard` | Includes batching, permit patterns (default) |
| `aggressive` | Adds L2 migration suggestions |

## MEV Risk Levels

| Risk Level | Description | Action |
|------------|-------------|--------|
| `none` | No MEV risk | Standard submission |
| `low` | Minimal risk | Optional Flashbots |
| `medium` | Moderate risk | Consider private mempool |
| `high` | Significant risk | Use Flashbots Protect |
| `critical` | Extreme risk | Flashbots + low slippage required |

## Integration with Existing Lux Components

The gas optimization system integrates seamlessly with existing Lux components:

- **Etherscan Lenses** — Builds on `GasOracle` and `GasEstimate` lenses for data
- **Prism Pattern** — All modules follow the standard `use Lux.Prism` pattern
- **Agent Integration** — Prisms can be directly used by Lux agents in workflows
- **Beams** — Can be composed into multi-step gas-optimized transaction flows

## Best Practices

1. **Always use EIP-1559** — More predictable costs, potential refunds on overpayment
2. **Batch when possible** — Same-target transactions save ~5,000 gas per tx
3. **Check MEV before swaps** — Large DEX swaps are prime MEV targets
4. **Simulate first** — Always simulate before submitting complex transactions
5. **Monitor congestion** — Use analytics to time non-urgent transactions
6. **Consider L2** — For cost-sensitive operations, L2 networks offer 95%+ savings
7. **Set fee caps** — Use `max_fee_cap_gwei` to prevent overspending during spikes
