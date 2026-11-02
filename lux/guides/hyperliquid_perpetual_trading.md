# Hyperliquid Perpetual Trading & Risk Orchestration

## Overview

The Hyperliquid Perpetual Trading module provides institutional-grade risk management, automated order routing, real-time position tracking, leverage enforcement, and automated liquidation protection for autonomous AI agents.

---

## Core Capabilities

1. **Advanced Order Routing (`Lux.Trading.Hyperliquid.OrderManager`):**
   - Supports Limit (GTC, IOC, ALO), Market, Stop Loss, Take Profit, and Trailing Stop orders.
   - Sizing and price precision validation.
   - Margin requirement calculation per order.

2. **Real-Time Position Tracking (`Lux.Trading.Hyperliquid.PositionTracker`):**
   - Tracks Long & Short positions with dynamic mark price updates.
   - Computes notional value, unrealized and realized PnL in USD, Return on Equity (ROE %), and exact liquidation prices.
   - Cross vs Isolated margin mode awareness.

3. **Margin & Leverage Controller (`Lux.Trading.Hyperliquid.MarginController`):**
   - Evaluates Initial Margin ($IM$) and Maintenance Margin ($MM$) requirements.
   - Real-time account equity, free collateral, and margin ratio monitoring.
   - Enforces per-coin maximum leverage boundaries (e.g. 50x for BTC/ETH, 20x for SOL/AVAX/ARB, 10x for altcoins).
   - Margin call alert trigger ($\ge 80\%$ margin ratio).

4. **Liquidation Protector & Auto De-Risking (`Lux.Trading.Hyperliquid.LiquidationProtector`):**
   - Calculates distance to liquidation:
     $$\text{Distance \%} = \frac{|P_{mark} - P_{liq}|}{P_{mark}} \times 100\%$$
   - Multi-tier alert classification:
     - **Safe:** Distance $> 15\%$
     - **Moderate:** Distance $8\% - 15\%$
     - **Warning:** Distance $4\% - 8\%$ (recommends 50% partial size reduction)
     - **Critical:** Distance $< 4\%$ (triggers emergency market close)

5. **Portfolio Risk Monitor & ASCII Dashboard (`Lux.Trading.Hyperliquid.RiskMonitor`):**
   - Portfolio-wide effective leverage and single-coin concentration ratio analysis.
   - Formatted ASCII performance and risk dashboard table for console, Discord, and Telegram alerts.

---

## Quickstart

### 1. Build and Price an Order

```elixir
alias Lux.Trading.Hyperliquid.OrderManager

{:ok, order} = OrderManager.build_order(%{
  coin: "ETH",
  is_buy: true,
  sz: 1.5,
  limit_px: 2800.0,
  order_type: "limit",
  tif: "gtc"
})

margin_needed = OrderManager.required_margin(order, 10)
IO.puts("Required margin: $\#{margin_needed}")
```

### 2. Track Position and Liquidation Proximity

```elixir
alias Lux.Trading.Hyperliquid.PositionTracker
alias Lux.Trading.Hyperliquid.LiquidationProtector

{:ok, pos} = PositionTracker.track_position(%{
  coin: "ETH",
  sz: 2.0,
  entry_px: 2600.0,
  mark_px: 2650.0,
  leverage: 10
})

IO.puts("Unrealized PnL: $\#{pos.unrealized_pnl} (ROE: \#{pos.roe_pct}%)")
IO.puts("Liquidation Price: $\#{pos.liquidation_px}")

risk = LiquidationProtector.evaluate_risk_tier(pos)
IO.puts("Risk Tier: \#{risk.tier} (\#{risk.distance_pct}% from liquidation)")
```

### 3. Evaluate Account Margin & Collateral

```elixir
alias Lux.Trading.Hyperliquid.MarginController

margin = MarginController.evaluate_account_margin(10_000.0, [pos])
IO.puts("Account Equity: $\#{margin.account_equity}")
IO.puts("Free Collateral: $\#{margin.free_collateral}")
IO.puts("Margin Ratio: \#{margin.margin_ratio}%")
```

### 4. Execute with PerpetualTradingBeam

```elixir
alias Lux.Beams.Trading.Hyperliquid.PerpetualTradingBeam

{:ok, result, execution_log} = PerpetualTradingBeam.run(%{
  coin: "ETH",
  sz: 1.0,
  entry_px: 2500.0,
  mark_px: 2550.0,
  leverage: 10,
  wallet_balance: 5000.0
})
```

---

## Prisms Reference

| Prism | Description |
| :--- | :--- |
| `Lux.Prisms.Trading.Hyperliquid.PlaceOrderPrism` | Validates parameters and formats perpetual orders |
| `Lux.Prisms.Trading.Hyperliquid.ManageMarginPrism` | Audits margin ratio, equity, and free collateral |
| `Lux.Prisms.Trading.Hyperliquid.TrackPositionsPrism` | Calculates notional, PnL, ROE %, and liquidation prices |
| `Lux.Prisms.Trading.Hyperliquid.CheckLiquidationRiskPrism` | Assesses liquidation proximity distance percentage |
| `Lux.Prisms.Trading.Hyperliquid.AutoDeriskPrism` | Generates protective size reduction or market close plans |
