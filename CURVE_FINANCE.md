# Curve Finance Integration — Spectral Finance Lux

## Overview

This module provides comprehensive Curve Finance integration for the Spectral Finance lux platform, enabling stablecoin management, yield optimization, gauge monitoring, and automated rebalancing strategies.

## Architecture

Built on the Lens/Prism/Beam architecture pattern:

- **Lenses** — Data collection and analysis modules
- **Prisms** — Data transformation and optimization modules
- **Beams** — Pipeline orchestration modules

## Modules

### Lenses

#### `Lux.Lenses.CurveFinance.PoolAnalyticsLens`
Fetches and analyzes Curve pool data including TVL, APY, volume, reserves, and historical performance.

```elixir
Lux.Lenses.CurveFinance.PoolAnalyticsLens.run(%{pool_address: "0xbebc44782c7db0a1a60cb6fe97d0b483032ff1c7"})
# => {:ok, %{pool: %{...}, tvl: 1_234_567_890, apy: 0.052, volume_24h: 45_678_901}}
```

#### `Lux.Lenses.CurveFinance.GaugeMonitoringLens`
Monitors gauge emissions, voting incentives, and gauge health metrics.

```elixir
Lux.Lenses.CurveFinance.GaugeMonitoringLens.run(%{gauge_address: "0xbBC81d23Ea2c3ec7e56D39693049825d3f869366"})
# => {:ok, %{gauge: %{...}, emissions: %{...}, voting_incentives: %{...}}}
```

#### `Lux.Lenses.CurveFinance.CrvRewardsLens`
Tracks CRV rewards and emissions for staked LP positions.

```elixir
Lux.Lenses.CurveFinance.CrvRewardsLens.run(%{wallet: "0x1234...5678", gauge: "0xbBC8..."})
# => {:ok, %{rewards: %{...}, claim_history: [...], recommendations: [...]}}
```

#### `Lux.Lenses.CurveFinance.StablecoinPricingLens`
Fetches stablecoin prices and monitors peg deviations.

```elixir
Lux.Lenses.CurveFinance.StablecoinPricingLens.run(%{tokens: ["DAI", "USDC", "USDT"]})
# => {:ok, %{prices: %{...}, peg_status: %{...}}}
```

### Prisms

#### `Lux.Prisms.CurveFinance.YieldOptimizerPrism`
Calculates optimal yield strategies across Curve pools.

```elixir
Lux.Prisms.CurveFinance.YieldOptimizerPrism.run(%{amount: 10_000, tokens: ["USDC"], risk_tolerance: :conservative})
# => {:ok, %{strategy: %{...}, expected_apy: 0.052, risk_score: 0.92}}
```

#### `Lux.Prisms.CurveFinance.RebalancingPrism`
Determines when and how to rebalance positions across pools.

```elixir
Lux.Prisms.CurveFinance.RebalancingPrism.run(%{current_pool: "0xbebc...", target_pool: "0x4c9a..."})
# => {:ok, %{action: :rebalance, expected_gain: 0.015, gas_cost: 12.60}}
```

#### `Lux.Prisms.CurveFinance.SlippageOptimizerPrism`
Calculates optimal swap routes to minimize slippage.

```elixir
Lux.Prisms.CurveFinance.SlippageOptimizerPrism.run(%{from: "USDC", to: "DAI", amount: 100_000})
# => {:ok, %{route: [...], slippage: 0.0001, estimated_output: 99990}}
```

#### `Lux.Prisms.CurveFinance.GaugesVotingPrism`
Optimizes gauge voting strategy for maximum CRV rewards.

```elixir
Lux.Prisms.CurveFinance.GaugesVotingPrism.run(%{veCRV_amount: 50_000, vote_count: 10})
# => {:ok, %{votes: [...], expected_apy: 0.025, total_incentive: 12500}}
```

### Beam

#### `Lux.Beams.CurveFinanceEngine`
Main entry point orchestrating the full Curve Finance workflow.

```elixir
# Analyze pools
Lux.Beams.CurveFinanceEngine.run(%{action: :analyze, pool: "0xbebc..."})

# Optimize yield
Lux.Beams.CurveFinanceEngine.run(%{action: :optimize, amount: 50_000, tokens: ["USDC"]})

# Monitor positions
Lux.Beams.CurveFinanceEngine.run(%{action: :monitor, wallet: "0x1234...5678"})

# Full portfolio cycle
Lux.Beams.CurveFinanceEngine.full_cycle(%{wallet: "0x1234...5678", amount: 50_000})
```

## Supported Pools

| Pool | Address | Coins | TVL | APY |
|------|---------|-------|-----|-----|
| 3pool | `0xbebc...` | DAI/USDC/USDT | $850M | 5.2% |
| stETH | `0x4c9a...` | ETH/stETH | $1.2B | 4.5% |
| TriCrypto | `0xa540...` | USDT/WBTC/WETH | $650M | 8.9% |
| MetaPool | `0x06df...` | FRAX/3CRV | $180M | 6.7% |

## Risk Levels

| Level | Min Risk Score | Description |
|-------|---------------|-------------|
| Conservative | 0.85 | Stablecoin-only pools |
| Moderate | 0.70 | Includes liquid staking |
| Aggressive | 0.50 | Includes crypto volatility pools |

## Testing

```bash
# Run all Curve Finance tests
mix test test/unit/lux/lenses/curve_finance/
mix test test/unit/lux/prisms/curve_finance/
mix test test/integration/curve_finance/

# Run specific test
mix test test/unit/lux/lenses/curve_finance/pool_analytics_lens_test.exs
```

## Integration

### With Other Spectral Modules

```elixir
# Combine with Hyperliquid for cross-protocol strategies
alias Lux.Beams.{CurveFinanceEngine, Hyperliquid.TradeRiskManagementBeam}

# Use Curve yields to fund Hyperliquid positions
{:ok, curve_result} = CurveFinanceEngine.run(%{action: :optimize, amount: 100_000, tokens: ["USDC"]})
# Use optimized yield to determine position sizing for Hyperliquid
```

## Configuration

No external configuration required. All modules use simulated data for development. Production deployment requires:

1. Curve Registry contract RPC endpoint
2. Etherscan API key for historical data
3. Chainlink price feed addresses
4. The Graph subgraph URL for pool data

## License

MIT — Spectral Finance
