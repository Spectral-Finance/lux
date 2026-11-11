# DeFi Analytics Integration: DeFiLlama & Dune Analytics (#88)

## Overview
`Lux.Lenses.DefiAnalytics.DefillamaDuneLens` integrates DeFiLlama TVL & yield pool intelligence with Dune Analytics parameterized SQL execution and automated anomaly/drawdown alerting.

## Usage
```elixir
alias Lux.Lenses.DefiAnalytics.DefillamaDuneLens

{:ok, tvl} = DefillamaDuneLens.analyze_protocol_tvl(%{
  name: "Morpho Blue",
  current_tvl_usd: 3_200_000_000.0,
  tvl_7d_ago_usd: 2_950_000_000.0,
  chain_tvls: %{"Ethereum" => 2_200_000_000.0, "Base" => 1_000_000_000.0}
})
```
