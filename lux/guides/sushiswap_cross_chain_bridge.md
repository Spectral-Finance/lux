# SushiSwap Integration and SushiXSwap Cross-Chain Bridge Guide

## Overview

The `Lux.Defi.SushiSwap` suite delivers a multi-chain AMM and cross-chain bridge architecture supporting SushiSwap V2, RouteProcessor multi-hop execution, MiniChefV2 staking rewards, and SushiXSwap v2 (Stargate/LayerZero cross-chain bridge integration) across Ethereum, Arbitrum One, Polygon, Optimism, and Base.

---

## Architectural Components

1. **`Lux.Defi.SushiSwap.PoolManager`**
   - Registry for official contract deployments across 5+ chains (Ethereum, Arbitrum, Polygon, Optimism, Base).
   - Manages RouteProcessor, SushiXSwap, BentoBox, and MiniChef contract addresses.

2. **`Lux.Defi.SushiSwap.SushiXSwap`**
   - Coordinates cross-chain swap routes:
     $$\text{Source Swap} \longrightarrow \text{Stargate Bridge} \longrightarrow \text{Destination Swap}$$
   - Calculates bridge fees, estimated time, and guaranteed minimum received amounts ($0.5\%$ slippage protection).

3. **`Lux.Defi.SushiSwap.MiniChef`**
   - Implements MiniChefV2 staking and SUSHI emission mechanics:
     $$\text{Accrued} = \frac{\text{Amount} \times \text{acc\_sushi\_per\_share}}{10^{12}} - \text{reward\_debt}$$
   - Handles deposit, harvest, and withdrawal operations.

4. **`Lux.Defi.SushiSwap.RouteProcessor`**
   - Multi-hop swap path finder with constant product pricing ($0.30\%$ fee tier).
   - Computes expected price impact across consecutive pools.

5. **`Lux.Defi.SushiSwap.BridgeMonitor`**
   - Enforces bridge safety parameters (verifies fee ratio $< 5\%$ and slippage tolerance).
   - Generates ASCII status tables for active and pending cross-chain transactions.

---

## Prisms

- `Lux.Prisms.Defi.SushiSwap.SushiPoolPrism`: Formats and inspects multi-chain pool states.
- `Lux.Prisms.Defi.SushiSwap.SushiXSwapPrism`: Quotes cross-chain swap rates and bridge fees.
- `Lux.Prisms.Defi.SushiSwap.MiniChefStakePrism`: Simulates LP staking and SUSHI harvesting.
- `Lux.Prisms.Defi.SushiSwap.RouteProcessorPrism`: Calculates multi-hop swap outputs and price impact.
- `Lux.Prisms.Defi.SushiSwap.BridgeSecurityPrism`: Validates bridge safety thresholds and slippage.

---

## Beam Workflow

`Lux.Beams.Defi.SushiSwap.SushiCrossChainSwapBeam` coordinates:
1. Verifies source pool liquidity via `SushiPoolPrism`.
2. Generates cross-chain swap route via `SushiXSwapPrism`.
3. Asserts safety and slippage limits via `BridgeSecurityPrism`.

---

## Quickstart

```elixir
# 1. Quote cross-chain swap from Ethereum to Arbitrum
{:ok, quote} = Lux.Prisms.Defi.SushiSwap.SushiXSwapPrism.run(%{
  src_chain: 1,
  dst_chain: 42161,
  src_token: "WETH",
  dst_token: "USDC",
  amount_in: 2.5,
  src_price_usd: 2500.0,
  dst_price_usd: 1.0
})

# 2. Check bridge transfer security
{:ok, safety} = Lux.Prisms.Defi.SushiSwap.BridgeSecurityPrism.run(%{
  amount_in_usd: 6250.0,
  fee_usd: quote.total_fee_usd,
  est_out_usd: quote.estimated_amount_out
})

# 3. Coordinate pipeline via SushiCrossChainSwapBeam
{:ok, result} = Lux.Beams.Defi.SushiSwap.SushiCrossChainSwapBeam.run(%{
  src_chain: 1,
  dst_chain: 42161,
  src_token: "WETH",
  dst_token: "USDC",
  amount_in: 2.5,
  src_price_usd: 2500.0,
  dst_price_usd: 1.0
})
```
