# Binance Exchange Integration

This guide covers the Binance exchange integration for Lux, providing access to both Spot and Futures trading APIs.

## Configuration

```elixir
config :lux, :api_keys,
  binance_api_key: System.get_env("BINANCE_API_KEY"),
  binance_secret_key: System.get_env("BINANCE_SECRET_KEY")
```

## Modules

| Component | Module | Purpose |
|-----------|--------|---------|
| Integration | `Lux.Integrations.Binance` | Auth helpers, HMAC-SHA256 signing |
| Client | `Lux.Integrations.Binance.Client` | HTTP client for Spot & Futures APIs |
| Market Data Lens | `Lux.Lenses.Binance.MarketData` | Ticker, orderbook, klines, 24h stats |
| Account Info Lens | `Lux.Lenses.Binance.AccountInfo` | Balances, positions, account summary |
| Spot Order Prism | `Lux.Prisms.Binance.SpotOrder` | Place/cancel/status spot orders |
| Futures Order Prism | `Lux.Prisms.Binance.FuturesOrder` | Place/cancel futures orders, leverage, margin |

## Market Data

```elixir
{:ok, %{symbol: "BTCUSDT", price: "50000.00"}} =
  Lux.Lenses.Binance.MarketData.focus(%{endpoint: "ticker", symbol: "BTCUSDT"})

{:ok, %{bids: bids, asks: asks}} =
  Lux.Lenses.Binance.MarketData.focus(%{endpoint: "depth", symbol: "BTCUSDT", limit: 10})

{:ok, %{klines: klines}} =
  Lux.Lenses.Binance.MarketData.focus(%{endpoint: "klines", symbol: "BTCUSDT", interval: "1h", limit: 100})

{:ok, %{symbol: "BTCUSDT", price: price}} =
  Lux.Lenses.Binance.MarketData.focus(%{endpoint: "ticker", symbol: "BTCUSDT", futures: true})
```

## Account Information

```elixir
{:ok, %{balances: balances}} =
  Lux.Lenses.Binance.AccountInfo.focus(%{endpoint: "balances"})

{:ok, %{positions: positions}} =
  Lux.Lenses.Binance.AccountInfo.focus(%{endpoint: "positions"})

{:ok, %{total_wallet_balance: balance, available_balance: available}} =
  Lux.Lenses.Binance.AccountInfo.focus(%{endpoint: "futures_account"})
```

## Spot Trading

```elixir
alias Lux.Prisms.Binance.SpotOrder

{:ok, %{order_id: id}} = SpotOrder.handler(%{
  action: "place",
  symbol: "BTCUSDT",
  side: "BUY",
  type: "LIMIT",
  quantity: "0.001",
  price: "50000.00",
  time_in_force: "GTC"
}, %{name: "MyAgent"})

{:ok, %{status: "CANCELED"}} = SpotOrder.handler(%{
  action: "cancel",
  symbol: "BTCUSDT",
  order_id: 123456
}, %{name: "MyAgent"})
```

## Futures Trading

```elixir
alias Lux.Prisms.Binance.FuturesOrder

{:ok, %{leverage: 10}} = FuturesOrder.handler(%{
  action: "set_leverage",
  symbol: "BTCUSDT",
  leverage: 10
}, %{name: "MyAgent"})

{:ok, %{order_id: id}} = FuturesOrder.handler(%{
  action: "place",
  symbol: "BTCUSDT",
  side: "BUY",
  type: "LIMIT",
  quantity: "0.001",
  price: "50000.00",
  time_in_force: "GTC"
}, %{name: "MyAgent"})
```

## Authentication

All signed endpoints use HMAC-SHA256 authentication. The client automatically:

1. Adds the `X-MBX-APIKEY` header
2. Appends a `timestamp` parameter
3. Computes and appends the `signature` parameter

## Rate Limits

- **Order endpoints**: 1,200 requests/min
- **Weight-based**: 6,000 weight/min
- **429 response**: Rate limit exceeded (`{:error, {:rate_limited, msg}}`)
- **418 response**: IP auto-banned (`{:error, {:ip_banned, msg}}`)

## WebSocket Feeds

This integration is REST-first. WebSocket streams can be added using Binance's stream endpoints (`wss://stream.binance.com:9443` for spot and `wss://fstream.binance.com` for futures).
