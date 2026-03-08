# Coinbase Exchange Integration

This guide covers the Coinbase Advanced Trade API integration for Lux.

## Overview

- **Market Data** — Products, ticker, orderbook, candles
- **Account Management** — Account balances, portfolio tracking
- **Order Management** — Create/cancel orders (market, limit, stop-limit)
- **Rate Limiting** — Built-in 429 handling

## Configuration

```elixir
config :lux, :api_keys,
  coinbase_api_key: "your-api-key",
  coinbase_api_secret: "your-api-secret"
```

## Authentication

Uses API Key + HMAC-SHA256 signing with headers:
- `CB-ACCESS-KEY` — API key
- `CB-ACCESS-SIGN` — HMAC-SHA256(timestamp + method + path + body)
- `CB-ACCESS-TIMESTAMP` — Unix timestamp

## Usage

### Market Data

```elixir
alias Lux.Lenses.Coinbase.MarketData

{:ok, products} = MarketData.get_products()
{:ok, ticker} = MarketData.get_ticker("BTC-USD")
{:ok, candles} = MarketData.get_candles("BTC-USD", %{start: "1704067200", end: "1704153600", granularity: "ONE_HOUR"})
{:ok, book} = MarketData.get_orderbook("BTC-USD")
```

### Accounts

```elixir
alias Lux.Lenses.Coinbase.Accounts

{:ok, accounts} = Accounts.list_accounts()
{:ok, account} = Accounts.get_account("account-uuid")
{:ok, portfolios} = Accounts.list_portfolios()
{:ok, portfolio} = Accounts.get_portfolio("portfolio-uuid")
```

### Orders

```elixir
alias Lux.Prisms.Coinbase.CreateOrder
alias Lux.Prisms.Coinbase.CancelOrder

# Market buy
{:ok, order} = CreateOrder.handler(%{product_id: "BTC-USD", side: "BUY", order_type: "market", amount: "100.00"}, %{name: "MyAgent"})

# Limit sell
{:ok, order} = CreateOrder.handler(%{product_id: "ETH-USD", side: "SELL", order_type: "limit", base_size: "1.0", limit_price: "3000.00"}, %{name: "MyAgent"})

# Cancel
{:ok, result} = CancelOrder.handler(%{order_ids: ["order-1"]}, %{name: "MyAgent"})
```

## Modules

| Module | Description |
|--------|-------------|
| `Lux.Integrations.Coinbase` | Auth helpers |
| `Lux.Integrations.Coinbase.Client` | HTTP client |
| `Lux.Lenses.Coinbase.MarketData` | Products, ticker, orderbook, candles |
| `Lux.Lenses.Coinbase.Accounts` | Account balances, portfolios |
| `Lux.Prisms.Coinbase.CreateOrder` | Place orders |
| `Lux.Prisms.Coinbase.CancelOrder` | Cancel orders |

## Error Handling

- `{:error, :invalid_credentials}` — Bad API key/secret
- `{:error, :rate_limited}` — 429 rate limit
- `{:error, {status, message}}` — API error

## API Reference

- Base URL: `https://api.coinbase.com/api/v3/brokerage`
- Rate limits: 10 req/sec per endpoint
- [Coinbase API docs](https://docs.cdp.coinbase.com/advanced-trade/docs/rest-api-overview)
