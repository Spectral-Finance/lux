# Curve Finance Integration and Stablecoin Management

Lux provides a complete Curve Finance integration (`Lux.Web3.Exchanges.Curve` and `Lux.Prisms.Web3.CurvePrism`) for stablecoin liquidity management, low-slippage swap routing, gauge staking, CRV boost optimization, and real-time peg health monitoring.

## Core Capabilities

1. **Pool Discovery & Registry**: Inspects StableSwap (`3pool`, `frax_usdc`, `crvusd_usdc`) and CryptoSwap (`tricrypto2`) pools, amplification factors (`A`), virtual prices, and base/CRV APYs.
2. **Swap Quoting (`get_dy`) & Optimal Routing**: Computes StableSwap and CryptoSwap invariant quotes, price impact in basis points, and multi-pool route comparisons.
3. **Liquidity Provision & Single-Sided Exit**: Supports balanced `add_liquidity` and `remove_liquidity` as well as single-token exit (`{:one_coin, symbol}`) with slippage bounds.
4. **Gauge Staking & `veCRV` Boost**: Stakes Curve LP tokens into liquidity gauges, calculates `veCRV` boost multipliers (`1.0x` to `2.5x`), and claims or auto-compounds CRV emissions.
5. **Peg Health Monitoring & Automated Rebalancing**: Detects reserve concentration skew, estimates implied stablecoin depeg, and generates emergency exit or yield-maximization rebalance plans.

## Usage Example

```elixir
alias Lux.Web3.Exchanges.Curve

# 1. Find the optimal route for swapping 250,000 USDC to USDT
{:ok, route} = Curve.find_best_route("USDC", "USDT", 250_000, max_slippage_bps: 20)

# 2. Add liquidity and stake in the Curve gauge with veCRV boost
{:ok, lp} = Curve.add_liquidity("3pool", [50_000, 50_000, 50_000], 140_000, wallet: wallet)
{:ok, staked} = Curve.stake_in_gauge("3pool", lp.lp_tokens_minted, wallet: wallet, vecrv_balance: 100_000)

# 3. Monitor stablecoin peg health and generate rebalancing recommendations
{:ok, health} = Curve.analyze_peg_health("3pool")
{:ok, plan} = Curve.optimize_yield_rebalance(wallet)
```
