# Binance Exchange Integration Guide

## Overview

The `Lux.Integrations.Binance` package provides a unified framework for interacting with Binance Spot and USDⓈ-M Perpetual Futures markets. It implements cryptographic authentication, rate limit tracking, REST and WebSocket connectors, position risk estimation, and workflow coordination via Lux Beams.

---

## Core Components

1. **`Lux.Integrations.Binance.Signer`**
   - HMAC-SHA256 signature signing with API secret keys.
   - Automatically injects unix millisecond timestamps and `recvWindow` security tolerances.
   - Formats `X-MBX-APIKEY` authentication headers.

2. **`Lux.Integrations.Binance.RateLimiter`**
   - Tracks 1-minute IP weight usage (1200 weight ceiling).
   - Enforces 10 orders per second rate limits.
   - Handles backoff penalties for HTTP 429 (Too Many Requests) and HTTP 418 (IP bans).

3. **`Lux.Integrations.Binance.RestClient`**
   - Standardizes Spot (`https://api.binance.com`) and Futures (`https://fapi.binance.com`) endpoints.
   - Supports production and testnet environments (`testnet.binance.vision` / `testnet.binancefuture.com`).
   - Normalizes API error payloads into structured errors.

4. **`Lux.Integrations.Binance.SpotTrading`**
   - Supports LIMIT, MARKET, STOP_LOSS_LIMIT, and TAKE_PROFIT_LIMIT orders.
   - Validates trading pairs, order sides (BUY/SELL), quantities, and Time-In-Force (GTC, IOC, FOK).
   - Prepares single and batch order cancellation requests.

5. **`Lux.Integrations.Binance.FuturesTrading`**
   - Supports USDⓈ-M Perpetual Futures contract orders.
   - Configures leverage (1x - 125x) and margin mode (ISOLATED vs CROSSED).
   - Calculates liquidation prices:
     $$\text{Liq Price (Long)} = \text{Entry} \times \left(1 - \frac{1}{\text{Leverage}} + \text{MMR}\right)$$
     $$\text{Liq Price (Short)} = \text{Entry} \times \left(1 + \frac{1}{\text{Leverage}} - \text{MMR}\right)$$
   - Computes unrealized PnL and return on equity (ROE%).

6. **`Lux.Integrations.Binance.WebsocketClient`**
   - Generates single and multiplexed stream URLs.
   - Parses typed payloads for depth books, individual trades, candlesticks (klines), and mark prices.

7. **`Lux.Integrations.Binance.Portfolio`**
   - Aggregates spot balances and converts equity into USDT equivalent.
   - Evaluates futures account margin health ratio and assigns safety states (`:safe`, `:warning`, `:critical`).

---

## Prisms

- `Lux.Prisms.Binance.SpotOrderPrism`: Validates and structures Spot orders.
- `Lux.Prisms.Binance.FuturesOrderPrism`: Validates and structures Perpetual Futures orders.
- `Lux.Prisms.Binance.AccountBalancePrism`: Computes aggregated portfolio balance and total equity in USDT.
- `Lux.Prisms.Binance.MarketDepthPrism`: Evaluates orderbook best bids, best asks, and spreads.
- `Lux.Prisms.Binance.PositionRiskPrism`: Assesses liquidation prices, ROE%, and unrealized PnL.

---

## Beam Workflow

`Lux.Beams.Binance.BinanceTradingBeam` connects the complete pipeline:
1. Validates market liquidity and spread with `MarketDepthPrism`.
2. Computes leverage safety and liquidation barrier via `PositionRiskPrism`.
3. Prepares order execution payload via `SpotOrderPrism`.

---

## Quickstart

```elixir
# 1. Inspect market spread
{:ok, depth} = Lux.Prisms.Binance.MarketDepthPrism.run(%{
  symbol: "BTCUSDT",
  bids: [[64500.0, 1.2], [64490.0, 3.5]],
  asks: [[64510.0, 0.8], [64520.0, 2.1]]
})

# 2. Check position risk & liquidation barrier
{:ok, risk} = Lux.Prisms.Binance.PositionRiskPrism.run(%{
  side: "BUY",
  entry_price: 64500.0,
  mark_price: 64750.0,
  quantity: 0.5,
  leverage: 10
})

# 3. Coordinate trade execution via Beam
{:ok, result} = Lux.Beams.Binance.BinanceTradingBeam.run(%{
  symbol: "BTCUSDT",
  side: "BUY",
  quantity: 0.5,
  price: 64500.0,
  leverage: 10,
  bids: [[64500.0, 1.2]],
  asks: [[64510.0, 0.8]]
})
```
