# Coinbase Advanced Trade Exchange Integration Guide

## Overview

The `Lux.Integrations.Coinbase` package implements advanced trading, real-time market data streaming, account portfolio monitoring, and automated execution workflows for the Coinbase Advanced Trade API v3.

---

## Architectural Components

1. **`Lux.Integrations.Coinbase.Signer`**
   - Implements Coinbase API authentication via HMAC-SHA256 signatures:
     $$\text{Signature} = \text{HMAC-SHA256}(\text{Secret}, \text{timestamp} + \text{method} + \text{path} + \text{body})$$
   - Prepares required `CB-ACCESS-KEY`, `CB-ACCESS-SIGN`, and `CB-ACCESS-TIMESTAMP` request headers.

2. **`Lux.Integrations.Coinbase.RateLimiter`**
   - Monitors REST endpoint traffic (30 requests/sec limit) and order placement frequency (100 orders/sec).
   - Manages automatic backoff on receiving HTTP 429 Too Many Requests responses.

3. **`Lux.Integrations.Coinbase.RestClient`**
   - Handles API routing for Production (`https://api.coinbase.com`) and Sandbox (`https://api-public.sandbox.exchange.coinbase.com`) environments.
   - Normalizes Coinbase errors and formats structured request payloads.

4. **`Lux.Integrations.Coinbase.OrderManager`**
   - Supports Limit (`limit_limit_gtc`, `limit_limit_gtd`), Market (`market_market_ioc`), and Stop-Limit (`stop_limit_stop_limit_gtc`) order types.
   - Generates compliant UUIDv4 client order IDs for transaction idempotency.
   - Manages batch order cancellation requests.

5. **`Lux.Integrations.Coinbase.MarketData`**
   - Maps user intervals (1m, 5m, 15m, 1h, 1d) to Coinbase candle granularities (`ONE_MINUTE`, `FIVE_MINUTE`, etc.).
   - Computes Level 2 orderbook depth, best bids, best asks, and spread metrics.

6. **`Lux.Integrations.Coinbase.AccountManager`**
   - Aggregates spot and fiat balances into net USD portfolio valuations.
   - Estimates maker and taker trading fees across VIP volume tiers.

7. **`Lux.Integrations.Coinbase.WebsocketClient`**
   - Formats public and authenticated subscription messages for `ticker`, `market_trades`, `candles`, and `level2` channels on `wss://advanced-trade-ws.coinbase.com`.
   - Normalizes incoming live market data feeds.

---

## Prisms

- `Lux.Prisms.Coinbase.OrderPrism`: Validates order parameters and generates Coinbase Advanced Trade payloads.
- `Lux.Prisms.Coinbase.AccountsPrism`: Computes aggregated net portfolio balance in USD.
- `Lux.Prisms.Coinbase.ProductCandlesPrism`: Formats and structures historical candlestick data.
- `Lux.Prisms.Coinbase.OrderbookPrism`: Computes orderbook spread, top bids, and top asks.
- `Lux.Prisms.Coinbase.FeeEstimatePrism`: Estimates trade execution fees and net transaction costs.

---

## Beam Workflow

`Lux.Beams.Coinbase.CoinbaseTradingBeam` coordinates:
1. Inspects Level 2 market depth and spread with `OrderbookPrism`.
2. Estimates trade execution fee with `FeeEstimatePrism`.
3. Prepares idempotent order payload with `OrderPrism`.

---

## Quickstart

```elixir
# 1. Inspect market orderbook spread
{:ok, ob} = Lux.Prisms.Coinbase.OrderbookPrism.run(%{
  product_id: "BTC-USD",
  bids: [%{"price_level" => "64800.0"}],
  asks: [%{"price_level" => "64810.0"}]
})

# 2. Estimate taker fee
{:ok, fee} = Lux.Prisms.Coinbase.FeeEstimatePrism.run(%{
  quantity: 0.5,
  price: 64800.0,
  fee_type: "taker"
})

# 3. Coordinate trade execution via Beam
{:ok, result} = Lux.Beams.Coinbase.CoinbaseTradingBeam.run(%{
  product_id: "BTC-USD",
  side: "BUY",
  base_size: 0.5,
  limit_price: 64800.0,
  fee_type: "taker",
  bids: [%{"price_level" => "64800.0"}],
  asks: [%{"price_level" => "64810.0"}]
})
```
