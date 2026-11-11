# Curve Finance Integration and Stablecoin Management (#81)

## Overview
`Lux.Prisms.Curve.StablecoinPoolPrism` provides stablecoin pool analysis, Curve StableSwap invariant (`D` and `get_dy`) slippage estimation, Liquidity Gauge `veCRV` boost (`1.0x`–`2.5x`) modeling, and automated risk-adjusted pool rebalancing.

## Usage
```elixir
alias Lux.Prisms.Curve.StablecoinPoolPrism
alias Lux.Prisms.Curve.StablecoinPoolPrism.{PoolState, GaugePosition}

pool = %PoolState{
  pool_id: "crvusd-usdc",
  name: "crvUSD/USDC",
  coins: ["crvUSD", "USDC"],
  balances: [25_000_000.0, 25_000_000.0],
  amp: 500,
  fee_bps: 4.0,
  base_apy: 5.4,
  crv_apr_min: 3.0,
  crv_apr_max: 7.5,
  extra_rewards_apr: 1.2
}

{:ok, swap} = StablecoinPoolPrism.estimate_swap(pool, 0, 1, 50_000.0)
```
