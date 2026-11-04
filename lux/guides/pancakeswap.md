# PancakeSwap Integration

Lux ships a set of prisms for PancakeSwap pool and yield-farming management across
multiple chains: reading pools and positions, building farming and liquidity
transactions, planning auto-compounding, comparing APYs, monitoring risk and planning
cross-chain moves.

## How it works

- **Reads** (pools, positions, allowances, quotes) use JSON-RPC `eth_call` through
  `Lux.Integrations.PancakeSwap.Client`. No API key is needed; public RPC endpoints are
  used by default and can be replaced per call with `rpc_url`.
- **Writes never sign or broadcast.** Prisms that change state return `steps`, an ordered
  list of **unsigned** transactions `%{name, chain_id, to, data, value}`. Sign and send
  them with your own wallet or signer. Lux never handles a private key for PancakeSwap.
- Amounts are wei values, passed as integers or decimal strings (so values above 2^53 are
  safe). Rates (`apr`, `apy`) are fractions: `0.25` means 25%.
- All prisms accept atom or string keys and return `{:ok, map}` or `{:error, message}`.

## Chains

| Chain      | Name         | Id     | Farming (MasterChef V2) | V2 router/factory |
|------------|--------------|--------|-------------------------|-------------------|
| BNB Chain  | `"bsc"`      | 56     | yes                     | yes               |
| Ethereum   | `"ethereum"` | 1      | pass `masterchef:`      | yes               |
| Arbitrum   | `"arbitrum"` | 42161  | pass `masterchef:`      | yes               |
| Base       | `"base"`     | 8453   | pass `masterchef:`      | yes               |

Chains are looked up by name or id (`Lux.Integrations.PancakeSwap.chain/1`). Contract
addresses live in `Lux.Integrations.PancakeSwap.chains/0`; every prism also accepts
`masterchef`, `router`, `factory` and `rpc_url` overrides, so you can target another
deployment or a fork. Please check addresses against the
[PancakeSwap docs](https://docs.pancakeswap.finance) before sending real funds.

## Prisms

All prisms live under `Lux.Prisms.PancakeSwap`.

| Prism                         | What it does                                                        |
|-------------------------------|---------------------------------------------------------------------|
| `PoolInfoPrism`               | Reads a MasterChef V2 pool, CAKE emissions and (with prices) its APR |
| `PositionsPrism`              | Staked LP and pending CAKE for positions on several chains          |
| `FarmTransactionPrism`        | Unsigned `stake`, `unstake`, `harvest`, `emergency_withdraw`         |
| `LiquidityTransactionPrism`   | Unsigned V2 `add` / `remove` liquidity with slippage protection     |
| `AutoCompoundPrism`           | Decides whether to compound and plans harvest → swap → add liquidity → restake |
| `ApyOptimizerPrism`           | Compound APY, best compounding frequency, pool ranking              |
| `RiskMonitorPrism`            | Impermanent loss, low TVL, pool concentration, stopped emissions    |
| `CrossChainPlanPrism`         | Which chain to move capital to, net of bridge fees                  |

### Pool information and APR

```elixir
{:ok, pool} =
  Lux.Prisms.PancakeSwap.PoolInfoPrism.run(%{
    chain: "bsc",
    pool_id: 2,
    cake_price_usd: 2.5,
    pool_tvl_usd: 40_000_000
  })

pool.lp_token      # LP token of the farm
pool.cake_per_year # CAKE emitted to this pool per year (wei, string)
pool.apr           # farming APR as a fraction
```

The yearly emission is `cakePerBlock * allocPoint / totalAllocPoint * blocks_per_year`.
`blocks_per_year` defaults to a per-chain value; pass `blocks_per_year:` if the chain's
block time differs.

### Position tracking (multi-chain)

```elixir
{:ok, result} =
  Lux.Prisms.PancakeSwap.PositionsPrism.run(%{
    address: "0x…",
    positions: [
      %{chain: "bsc", pool_id: 2},
      %{chain: "base", pool_id: 1, masterchef: "0x…"}
    ]
  })

result.total_pending_cake     # sum over all chains that responded
result.pending_cake_by_chain  # %{"bsc" => "…", "base" => "…"}
result.positions              # per-position status: "ok" or "error" with a message
```

A failing chain is reported as an `"error"` entry and never fails the whole call.

### Staking, harvesting and unstaking

```elixir
{:ok, %{steps: steps}} =
  Lux.Prisms.PancakeSwap.FarmTransactionPrism.run(%{
    chain: "bsc",
    action: "stake",
    pool_id: 2,
    owner: "0x…",
    amount: "1000000000000000000"
  })

# steps == [approve (only if the allowance is too low), deposit]
```

`action: "harvest"` collects pending CAKE (`deposit(pid, 0)`), `"unstake"` withdraws
`amount`, and `"emergency_withdraw"` withdraws everything and forfeits pending rewards.

### Liquidity

```elixir
Lux.Prisms.PancakeSwap.LiquidityTransactionPrism.run(%{
  chain: "bsc",
  action: "add",
  owner: "0x…",
  token_a: "0x…",
  token_b: "0x…",
  amount_a_desired: "1000000000000000000",
  amount_b_desired: "500000000000000000",
  slippage_bps: 50
})
```

Minimum amounts are computed with integer math from `slippage_bps` (default 50 = 0.5%).
`action: "remove"` needs `liquidity`, `expected_amount_a` and `expected_amount_b`; the
pair is looked up through the factory unless `lp_token` is given. The deadline defaults to
20 minutes from now (`deadline:` or `now:` override it).

### Auto-compounding and reward reinvestment

```elixir
{:ok, plan} =
  Lux.Prisms.PancakeSwap.AutoCompoundPrism.run(%{
    chain: "bsc",
    pool_id: 2,
    owner: "0x…",
    cake_price_usd: 2.5,
    gas_cost_usd: 0.6,
    min_profit_ratio: 3
  })

plan.should_compound # true when pending reward >= 3 x gas cost
plan.steps           # harvest, approvals, swaps, add_liquidity, restake deposit
```

The pending CAKE is read from chain unless `pending_cake` (wei) is given. Half of the
CAKE is swapped into each pair token (a CAKE side is not swapped); swap outputs come from
`getAmountsOut` quotes reduced by `slippage_bps`, so the liquidity step always has the
tokens it needs. The restaked LP amount is estimated from the pair reserves and total
supply (reduced by `slippage_bps`), so a little dust LP may stay in the wallet. Use
`path_token0` / `path_token1` to route a swap through another token (for example WBNB).

Run your automation by calling the prism on a schedule (for example from a Lux agent or
`Lux.Beam`), signing the returned steps with your wallet when `should_compound` is true.

### APY tracking and optimization

```elixir
{:ok, result} =
  Lux.Prisms.PancakeSwap.ApyOptimizerPrism.run(%{
    pools: [%{id: "cake-bnb", apr: 0.4}, %{id: "usdt-busd", apr: 0.1}],
    position_usd: 10_000,
    gas_cost_usd: 0.5
  })

result.best_pool
# each pool: apy at `compounds_per_year` (default 365), best_compounds_per_year, net_apy
```

APY is `(1 + apr / n) ^ n - 1`; the net APY subtracts `n * gas_cost_usd / position_usd`.
Combine it with `PoolInfoPrism` (which returns each pool's `apr`) to rank real pools.

### Risk monitoring

```elixir
Lux.Prisms.PancakeSwap.RiskMonitorPrism.run(%{
  entry_price_ratio: 100,
  current_price_ratio: 400,
  pool_tvl_usd: 250_000,
  position_usd: 10_000,
  cake_per_block: "0"
})
# => risk_level "high", alerts for impermanent loss, low TVL and stopped emissions
```

### Cross-chain planning

```elixir
{:ok, plan} =
  Lux.Prisms.PancakeSwap.CrossChainPlanPrism.run(%{
    chains: [
      %{chain: "bsc", apr: 0.12, position_usd: 20_000},
      %{chain: "arbitrum", apr: 0.35, position_usd: 0}
    ],
    bridge_fee_usd: 15,
    horizon_days: 365
  })

plan.recommended  # true
plan.moves        # [%{from_chain: "bsc", to_chain: "arbitrum", net_gain_usd: …, steps: [bridge]}]
```

The prism recommends moves and returns a `bridge` step descriptor; it does not build
bridge calldata. Execute the bridge with the PancakeSwap bridge or Stargate, then use
`FarmTransactionPrism` and `LiquidityTransactionPrism` with `chain:` set to the
destination chain to re-enter the farm there.

## Limitations

- Farming uses MasterChef V2 (V2 LP pairs). PancakeSwap V3 NFT positions are not covered.
- Some tokens (for example USDT on Ethereum) require resetting an allowance to `0` before
  setting a new one; the `approve` steps set the exact required amount.
- Block times differ per chain and change over time; check `blocks_per_year` when you rely
  on absolute APR numbers.

## Testing

Unit tests mock the RPC endpoint with `Req.Test` (`Test.Support.PancakeSwapRpc`) and need
no network:

```bash
mix test.unit
```

`test/integration/pancakeswap_test.exs` makes read-only calls against public RPC endpoints:

```bash
mix test.integration
```

Set `PANCAKESWAP_RPC_URL` to use your own BNB Smart Chain endpoint.
