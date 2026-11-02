# Curve Finance Integration and Stablecoin Management

## Overview

The Curve Finance Integration module provides decentralized, high-efficiency stablecoin management, StableSwap invariant modeling, automated liquidity gauge staking, veCRV yield boost optimization, and imbalance rebalancing for autonomous AI agents.

---

## Core Features

1. **StableSwap Invariant Engine (`Lux.Defi.Curve.Math`):**
   - Precise Newton-Raphson approximation for StableSwap invariant $D$:
     $$A \cdot n^n \sum x_i + D = A \cdot D \cdot n^n + \frac{D^{n+1}}{n^n \prod x_i}$$
   - Swap output calculation (`get_dy/6`) with accurate pool fee deductions.
   - Multi-coin deposit and withdrawal LP token mint calculations.
   - veCRV working balance and boost formula:
     $$w_i = \min\left(l_i, 0.4 \cdot l_i + 0.6 \cdot L \cdot \frac{v_i}{V}\right)$$
     yielding boosts from 1.0x (unboosted) to 2.5x (max boosted).

2. **Pool Registry & Virtual Price Tracking (`Lux.Defi.Curve.PoolManager`):**
   - Pre-configured registry for major stablecoin pools: 3pool (DAI/USDC/USDT), crvUSD pools, fraxUSDC, and liquid staking tokens.
   - Exact virtual price tracking ($D / \text{total\_lp\_supply}$).
   - Coin balance skew and depeg threshold monitoring.

3. **Position Lifecycle Management (`Lux.Defi.Curve.PositionManager`):**
   - Deposit and balanced withdrawal across all pool coins.
   - Real-time USD portfolio valuation based on pool virtual price.

4. **Curve Gauge Staking & veCRV Boost (`Lux.Defi.Curve.GaugeManager`):**
   - Staking and unstaking LP tokens into Curve `LiquidityGauge`.
   - Automated CRV reward claiming.
   - Boost multiplier and max-boost threshold tracking.

5. **Imbalance Rebalancing Engine (`Lux.Defi.Curve.RebalanceEngine`):**
   - Detects pool imbalances to harvest positive slippage bonuses.
   - Directs deposits to the scarcest under-represented coin.
   - Depeg risk alerting.

6. **Yield Optimization & Auto-Compounding (`Lux.Defi.Curve.YieldOptimizer`):**
   - Combines trading fee base APY with boosted CRV gauge rewards.
   - Auto-compounding reinvestment plans and harvest threshold viability checks.

7. **Health Monitoring & ASCII Dashboard (`Lux.Defi.Curve.Monitor`):**
   - Stability score scoring (0-100%).
   - ASCII multi-pool performance dashboard table.

---

## Quickstart

### 1. Pool Analysis & Virtual Price

```elixir
alias Lux.Defi.Curve.PoolManager

balances = [1000 * 10^18, 1000 * 10^18, 1000 * 10^18]
vp = PoolManager.calculate_virtual_price(balances, 2000, 3000 * 10^18)
IO.puts("Virtual Price: \#{vp}")
```

### 2. veCRV Gauge Boost Calculation

```elixir
alias Lux.Defi.Curve.GaugeManager

metrics = GaugeManager.calculate_boost(1000.0, 50_000.0, 500_000.0, 1_000_000.0)
IO.puts("Gauge Boost: \#{metrics.boost}x (Max Boosted: \#{metrics.max_boosted?})")
```

### 3. Rebalance Skew & Harvest Bonuses

```elixir
alias Lux.Defi.Curve.RebalanceEngine

case RebalanceEngine.evaluate_imbalance([1000, 600, 1000]) do
  %{imbalanced?: true, preferred_deposit_coin_index: idx, bonus_estimated_pct: bonus} ->
    IO.puts("Deposit coin index \#{idx} to receive +\#{bonus}% bonus LP tokens")

  _ ->
    IO.puts("Pool is balanced")
end
```

### 4. Executing with StablecoinManagementBeam

```elixir
alias Lux.Beams.Defi.Curve.StablecoinManagementBeam

{:ok, result, execution_log} = StablecoinManagementBeam.run(%{
  pool_id: "3pool",
  balances: [1_000_000_000_000_000_000_000, 1_000_000_000_000_000_000_000, 1_000_000_000_000_000_000_000],
  amp: 2000,
  user_lp: 5000.0,
  total_gauge_lp: 500_000.0,
  user_vecrv: 10_000.0,
  unclaimed_crv: 50.0
})
```

---

## Prisms Reference

| Prism | Description |
| :--- | :--- |
| `Lux.Prisms.Defi.Curve.AnalyzePoolPrism` | Computes virtual price, skew, and health score |
| `Lux.Prisms.Defi.Curve.DepositAndStakePrism` | Mints LP tokens and stakes into gauge |
| `Lux.Prisms.Defi.Curve.ClaimAndCompoundPrism` | Plans auto-compounding harvest swaps |
| `Lux.Prisms.Defi.Curve.CheckGaugeBoostPrism` | Calculates veCRV boost and working balance |
| `Lux.Prisms.Defi.Curve.RebalanceStablePoolPrism` | Evaluates coin skew and positive slippage |
