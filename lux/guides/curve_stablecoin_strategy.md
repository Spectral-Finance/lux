# Curve stablecoin strategy helpers

Lux includes side-effect-free helpers for planning Curve stablecoin pool allocation before any wallet, signer, or RPC executor is involved.

```elixir
pools = [
  %{
    name: "3pool",
    base_apy: 2.1,
    crv_apy: 1.4,
    volume_apy: 0.3,
    slippage_bps: 4,
    balances: [100, 100, 100],
    gauge_working_supply: 80,
    gauge_total_supply: 100,
    tvl_usd: 10_000_000
  }
]

Lux.Defi.Curve.StablecoinStrategy.rank_pools(pools,
  min_tvl_usd: 1_000_000,
  max_slippage_bps: 25
)
```

The ranking output includes gross APY, slippage, imbalance, utilization and a concise rationale. `rebalance_plan/3` converts current holdings into target positions and returns deposit/withdraw/hold instructions with `requires_signature: false` and `requires_gas: false`, making the module safe to use inside agent planning workflows.

This module is intentionally transaction-free. A future executor can consume its plan and handle Curve pool deposits, LP withdrawals, gauge staking, and CRV claims only after explicit wallet authorization.
