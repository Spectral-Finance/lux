# PancakeSwap Integration and Multi-Chain Yield Farming Guide

## Overview

The `Lux.Defi.PancakeSwap` module provides an enterprise-grade yield farming, MasterChef staking, auto-compounding, and cross-chain routing suite for PancakeSwap v2, v3, and MasterChef contracts across multiple EVM networks (BNB Smart Chain, Ethereum, Arbitrum One, and Base).

---

## Architecture Components

1. **`Lux.Defi.PancakeSwap.PoolManager`**
   - Registry for official PancakeSwap deployments (Factory, Router, MasterChef, CAKE token addresses).
   - Validates pool parameters across BSC (56), Ethereum (1), Arbitrum (42161), and Base (8453).

2. **`Lux.Defi.PancakeSwap.MasterChef`**
   - Implements PancakeSwap MasterChef V2/V3 reward logic.
   - Calculates pending CAKE emissions using high-precision math:
     $$\text{accumulated} = \frac{\text{amount} \times \text{acc\_cake\_per\_share}}{10^{12}}$$
     $$\text{pending} = \text{accumulated} - \text{reward\_debt}$$
   - Handles deposits, withdrawals, and harvesting.

3. **`Lux.Defi.PancakeSwap.FarmingEngine`**
   - Computes 24h trading fee APR and CAKE emission APR.
   - Projects daily compounded APY ($A = (1 + r/365)^{365} - 1$).
   - Determines harvest profitability based on gas thresholds.

4. **`Lux.Defi.PancakeSwap.Autocompounder`**
   - Generates automated reinvestment strategies: swaps harvested CAKE into 50/50 token pairs, estimates new LP minting, and re-stakes into MasterChef.

5. **`Lux.Defi.PancakeSwap.CrossChainRouter`**
   - Coordinates LayerZero OFT and Stargate cross-chain bridge routes for CAKE and liquidity tokens between BSC, Arbitrum, Base, and Ethereum.

6. **`Lux.Defi.PancakeSwap.Monitor`**
   - Renders ASCII performance dashboard tables for monitoring multi-chain farm positions, yields, and status.

---

## Prisms

- `Lux.Prisms.Defi.PancakeSwap.GetPoolApyPrism`: Calculates pool fee APR and CAKE farming APR.
- `Lux.Prisms.Defi.PancakeSwap.StakeFarmPrism`: Executes or simulates MasterChef staking deposits.
- `Lux.Prisms.Defi.PancakeSwap.HarvestRewardsPrism`: Harvests pending CAKE rewards.
- `Lux.Prisms.Defi.PancakeSwap.AutoCompoundPrism`: Evaluates and plans farm compounding.
- `Lux.Prisms.Defi.PancakeSwap.BridgeTokensPrism`: Formulates cross-chain asset bridging plans.

---

## Beam Workflow

`Lux.Beams.Defi.PancakeSwap.YieldFarmingBeam` coordinates the entire pipeline:
1. Calculates live APY metrics via `GetPoolApyPrism`.
2. Plans auto-compounding viability via `AutoCompoundPrism`.
3. Stakes into MasterChef via `StakeFarmPrism`.

---

## Quickstart Example

```elixir
# 1. Check pool yields
{:ok, apy} = Lux.Prisms.Defi.PancakeSwap.GetPoolApyPrism.run(%{
  tvl_usd: 2_500_000.0,
  daily_vol_usd: 400_000.0,
  cake_price_usd: 2.45
})

# 2. Plan auto-compounding
{:ok, plan} = Lux.Prisms.Defi.PancakeSwap.AutoCompoundPrism.run(%{
  pending_cake: 50.0,
  cake_price_usd: 2.45,
  price0_usd: 2600.0,
  price1_usd: 1.0
})

# 3. Coordinate workflow with YieldFarmingBeam
{:ok, result} = Lux.Beams.Defi.PancakeSwap.YieldFarmingBeam.run(%{
  user_address: "0x1111222233334444555566667777888899990000",
  pid: 2,
  amount: 1_000_000_000_000_000_000,
  tvl_usd: 2_500_000.0,
  daily_vol_usd: 400_000.0,
  cake_price_usd: 2.45
})
```
