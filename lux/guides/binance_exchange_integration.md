# Binance Exchange Integration (#84)

## Overview
`Lux.Prisms.Binance.ExchangePrism` integrates Binance Spot (`/api/v3/*`) and USD-M Perpetual Futures (`/fapi/v1/*`) REST APIs, multiplexed WebSocket streams, portfolio valuation, and `X-MBX-USED-WEIGHT-1M` rate limit compliance.

## Usage
```elixir
alias Lux.Prisms.Binance.ExchangePrism

{:ok, order} = ExchangePrism.build_spot_order(%{
  symbol: "BTCUSDT",
  side: "BUY",
  type: "LIMIT",
  quantity: 0.25,
  price: 88_500.0
})
```
