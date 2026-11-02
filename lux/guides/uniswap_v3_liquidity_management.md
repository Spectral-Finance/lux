# Uniswap V3 Integration and Liquidity Management

## Overview

The Uniswap V3 Liquidity Management framework provides institutional-grade automation, concentrated liquidity optimization, risk control, and yield auto-compounding for autonomous AI agents operating on Uniswap V3.

---

## Core Capabilities

1. **Precision Concentrated Liquidity Math (`Lux.Defi.UniswapV3.Math`):**
   - Exact Q64.96 fixed-point arithmetic (`sqrtPriceX96` $\leftrightarrow$ Price $\leftrightarrow$ Tick).
   - Liquidity amounts calculations for single-sided (out-of-range) and dual-sided (in-range) positions.
   - Strict fee-tier tick spacing alignment (`Math.nearest_usable_tick/2`).

2. **Pool Discovery & Deterministic Addressing (`Lux.Defi.UniswapV3.PoolManager`):**
   - CREATE2 deterministic address calculation matching Uniswap V3 Factory.
   - Comprehensive fee tier registry: 1 bp (0.01%), 5 bps (0.05%), 30 bps (0.30%), 100 bps (1.00%).
   - Intelligent fee tier recommendation based on token pair volatility profiles.

3. **Multi-Pool Position Management (`Lux.Defi.UniswapV3.PositionManager`):**
   - Structured position lifecycle: minting, liquidity additions, liquidity reductions, fee withdrawals, and asset valuation in USD.
   - Fast active in-range verification (`in_range?/2`).

4. **Dynamic Price Range Optimization (`Lux.Defi.UniswapV3.RangeOptimizer`):**
   - Range strategies: `:narrow` (+/- 3%), `:moderate` (+/- 10%), `:wide` (+/- 25%), `:bullish` (-5%/+20%), `:bearish` (-20%/+5%), and `:volatility` (implied volatility based).
   - Capital efficiency multiplier quantification relative to full-range Uniswap V2.

5. **Automated Rebalancing Engine (`Lux.Defi.UniswapV3.RebalanceEngine`):**
   - Detects out-of-range positions and boundary-approaching thresholds (default 85% proximity).
   - Evaluates economic viability: ensures gas overhead does not consume position capital.
   - Generates executable rebalance plans.

6. **Impermanent Loss Modeling & Stop-Loss (`Lux.Defi.UniswapV3.ImpermanentLoss`):**
   - Standard V2 vs Concentrated V3 amplified IL quantification.
   - Net PnL accounting (fees collected vs impermanent loss impact).
   - Automated stop-loss triggers on adverse price divergence.

7. **Yield Optimization & Auto-Compounding (`Lux.Defi.UniswapV3.YieldOptimizer`):**
   - Annualized fee APR and APY projection.
   - Optimal token reinvestment ratio calculation with automated swap planning.

8. **Performance Monitoring & Dashboard (`Lux.Defi.UniswapV3.Monitor`):**
   - Real-time position health scoring (0-100%).
   - ASCII multi-pool performance dashboard table.

---

## Quickstart

### 1. Optimize Range and Calculate Efficiency

```elixir
alias Lux.Defi.UniswapV3.RangeOptimizer

# Optimize a +/- 10% range around current tick for a 0.3% pool
{:ok, range} = RangeOptimizer.calculate_range(200_000, 3000, :moderate)

IO.puts("Optimal Lower Tick: \#{range.tick_lower}")
IO.puts("Optimal Upper Tick: \#{range.tick_upper}")
IO.puts("Capital Efficiency: \#{range.efficiency}x")
```

### 2. Check Position Health & Impermanent Loss

```elixir
alias Lux.Defi.UniswapV3.Monitor

report = Monitor.check_health(position, current_tick, 2500.0, 2550.0, 2400.0, 2600.0)

if report.in_range? do
  IO.puts("Position is healthy (Score: \#{report.health_score}%)")
else
  IO.puts("Position is OUT OF RANGE! Triggering rebalance...")
end
```

### 3. Automated Rebalancing

```elixir
alias Lux.Defi.UniswapV3.RebalanceEngine

case RebalanceEngine.plan_rebalance(position, current_tick, :moderate) do
  {:ok, %{action: :rebalance, viable?: true} = plan} ->
    IO.puts("Rebalancing position to [\#{plan.new_tick_lower}, \#{plan.new_tick_upper}]")

  {:ok, %{action: :hold}} ->
    IO.puts("Position remains optimal, holding")
end
```

### 4. Executing with LiquidityManagementBeam

```elixir
alias Lux.Beams.Defi.UniswapV3.LiquidityManagementBeam

{:ok, result, execution_log} = LiquidityManagementBeam.run(%{
  position: my_position,
  current_tick: 200_000,
  fee: 3000,
  strategy: "moderate",
  entry_price: 2500.0,
  current_price: 2520.0,
  price_lower: 2350.0,
  price_upper: 2650.0
})
```

---

## Prisms Reference

| Prism | Description |
| :--- | :--- |
| `Lux.Prisms.Defi.UniswapV3.CreatePositionPrism` | Validates parameters and mints concentrated position |
| `Lux.Prisms.Defi.UniswapV3.OptimizeRangePrism` | Computes spaced lower/upper ticks and efficiency ratio |
| `Lux.Prisms.Defi.UniswapV3.CheckPositionHealthPrism` | Assesses in-range status, health score, and IL |
| `Lux.Prisms.Defi.UniswapV3.CollectAndReinvestPrism` | Computes fee auto-compounding swap allocations |
| `Lux.Prisms.Defi.UniswapV3.RebalancePositionPrism` | Evaluates rebalance need and generates new boundaries |
