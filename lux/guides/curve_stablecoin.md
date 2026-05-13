# Curve Stablecoin Management

`Lux.Integrations.Curve.Stablecoin` provides a deterministic planning and
analytics layer for Curve Finance stablecoin operations. It does not approve
tokens, sign transactions, or move funds. Live adapters can use the output after
a separate signing policy approves execution.

The module covers:

- pool position normalization and summaries
- gauge stake, unstake, and claim-rewards action plans
- CRV reward value and APR projection
- pool scoring and risk flags
- slippage policy checks
- target-weight rebalance recommendations
- combined yield reports

## Position Summary

```elixir
alias Lux.Integrations.Curve.Stablecoin

summary =
  Stablecoin.position_summary([
    %{
      pool: "3pool",
      gauge: "0xgauge",
      lp_balance: "10",
      staked_balance: "8",
      share_value_usd: "1000",
      base_apr: 0.04,
      crv_apr: 0.02,
      rewards: [%{token: "CRV", amount: "12.5"}],
      coins: [%{symbol: "USDC", balance: "500"}]
    }
  ])

summary.weighted_apr
#=> 0.06
```

## Gauge Plans

Gauge plans are side-effect descriptions, not transactions.

```elixir
{:ok, plan} =
  Stablecoin.gauge_plan(:stake, %{
    gauge: "0xgauge",
    lp_token: "0xlp",
    amount: "12.5",
    user: "0xuser"
  })

plan.requires_signature?
#=> true
```

Supported actions:

- `:stake`
- `:unstake`
- `:claim_rewards`

## Reward Projection

```elixir
Stablecoin.reward_projection(%{
  staked_value_usd: 1000,
  crv_per_day: 2,
  crv_price_usd: 0.5,
  boost_multiplier: 1.5
})
#=> %{annual_reward_value_usd: 547.5, crv_apr: 0.5475, ...}
```

## Pool Analysis

```elixir
Stablecoin.pool_analysis([
  %{
    pool: "3pool",
    tvl_usd: 500_000_000,
    base_apr: 0.025,
    crv_apr: 0.015,
    volume_24h_usd: 20_000_000,
    virtual_price: 1.02,
    imbalance_bps: 20
  }
])
```

Scoring combines APR, liquidity, volume, and imbalance penalty. Risk flags call
out low liquidity, pool imbalance, and invalid virtual price inputs.

## Slippage Checks

```elixir
Stablecoin.slippage_check(
  %{expected_amount: 1000, minimum_amount: 997},
  %{max_slippage_bps: 40}
)
#=> %{slippage_bps: 30.0, allowed?: true, ...}
```

## Rebalancing

```elixir
Stablecoin.rebalance_plan(
  [
    %{pool: "3pool", share_value_usd: 1200},
    %{pool: "fraxusdc", share_value_usd: 800}
  ],
  %{"3pool" => 0.5, "fraxusdc" => 0.5},
  %{threshold_usd: 50}
)
```

The plan returns add/remove liquidity recommendations and marks whether any
move requires a signature.
