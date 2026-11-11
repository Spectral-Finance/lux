# Coinbase Exchange Integration (#83)

## Overview
`Lux.Prisms.Coinbase.AdvancedTradePrism` integrates Coinbase Advanced Trade v3 (`https://api.coinbase.com/api/v3/brokerage`) authentication, Spot/Stop-Limit order placement, WebSocket feeds, multi-account portfolio aggregation, historical candle normalization, and rate limit compliance.

## Usage
```elixir
alias Lux.Prisms.Coinbase.AdvancedTradePrism

{:ok, order} = AdvancedTradePrism.build_order(%{
  client_order_id: "lux-cb-001",
  product_id: "ETH-USD",
  side: "BUY",
  order_type: :limit_gtc,
  base_size: 1.5,
  limit_price: 3_150.0
})
```
