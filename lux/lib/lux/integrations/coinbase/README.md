# Coinbase Advanced Trade Integration

## Overview

This module provides a comprehensive integration with the [Coinbase Advanced Trade API](https://docs.cdp.coinbase.com/coinbase-app/advanced-trade-apis/rest-api), enabling autonomous agents to interact with Coinbase exchange for market data retrieval, order management, and real-time data streaming.

## Architecture

The integration follows the Lux framework patterns:

- **Lenses** (read-only data access) — Fetch market data, account info, and order history
- **Prisms** (actions) — Create orders, cancel orders, manage trades
- **Integration Client** — JWT-authenticated HTTP client for the Coinbase API
- **WebSocket** — Real-time market data streaming

## Authentication

Coinbase Advanced Trade API uses JWT (JSON Web Token) authentication with ES256 (ECDSA P-256) signing. Each API request requires a unique JWT that includes the HTTP method and request path.

### Configuration

```elixir
config :lux, :api_keys,
  coinbase_api_key: "organizations/{org_id}/apiKeys/{key_id}",
  coinbase_api_secret: "-----BEGIN EC PRIVATE KEY-----\n...\n-----END EC PRIVATE KEY-----\n"
```

### Creating API Keys

1. Navigate to [CDP Secret API Keys](https://portal.cdp.coinbase.com/projects/api-keys)
2. Click **Create API key**
3. **Important**: Select **ECDSA** as the signature algorithm (Ed25519 is NOT supported)
4. Set appropriate permissions: `view` for read-only, `trade` for orders, `transfer` for fund movements
5. Secure your private key

## Components

### Lenses (Market Data & Read Operations)

| Module | Description |
|--------|-------------|
| `Lux.Lenses.Coinbase.ProductsLens` | List all available trading products |
| `Lux.Lenses.Coinbase.ProductLens` | Get details for a specific product |
| `Lux.Lenses.Coinbase.AccountsLens` | List trading accounts and balances |
| `Lux.Lenses.Coinbase.TickerLens` | Get recent market trades for a product |
| `Lux.Lenses.Coinbase.CandlesLens` | Get historical OHLCV candle data |
| `Lux.Lenses.Coinbase.OrderBookLens` | Get the order book for a product |
| `Lux.Lenses.Coinbase.BestBidAskLens` | Get best bid/ask prices |
| `Lux.Lenses.Coinbase.OrdersLens` | List historical orders |
| `Lux.Lenses.Coinbase.FillsLens` | List order fills (executions) |
| `Lux.Lenses.Coinbase.FeesLens` | Get fee tier and transaction summary |

### Prisms (Trading Actions)

| Module | Description |
|--------|-------------|
| `Lux.Prisms.Coinbase.CreateOrder` | Create market, limit, or stop-limit orders |
| `Lux.Prisms.Coinbase.CancelOrders` | Cancel one or more orders (batch) |
| `Lux.Prisms.Coinbase.GetOrder` | Get details of a specific order |

### Integration Modules

| Module | Description |
|--------|-------------|
| `Lux.Integrations.Coinbase` | Common settings and auth helpers |
| `Lux.Integrations.Coinbase.Client` | JWT-authenticated HTTP client |
| `Lux.Integrations.Coinbase.WebSocket` | Real-time market data streaming |

## Usage Examples

### Market Data

```elixir
# List all products
{:ok, %{products: products}} = Lux.Lenses.Coinbase.ProductsLens.focus()

# Get BTC-USD ticker
{:ok, %{trades: trades, best_bid: bid, best_ask: ask}} =
  Lux.Lenses.Coinbase.TickerLens.focus(%{product_id: "BTC-USD", limit: 10})

# Get hourly candles
{:ok, %{candles: candles}} = Lux.Lenses.Coinbase.CandlesLens.focus(%{
  product_id: "BTC-USD",
  start: "1704067200",
  end: "1704153600",
  granularity: "ONE_HOUR"
})

# Get order book
{:ok, %{bids: bids, asks: asks}} =
  Lux.Lenses.Coinbase.OrderBookLens.focus(%{product_id: "BTC-USD", limit: 10})
```

### Account Management

```elixir
# List accounts
{:ok, %{accounts: accounts}} = Lux.Lenses.Coinbase.AccountsLens.focus()

# Get fee summary
{:ok, %{total_volume: volume, fee_tier: tier}} = Lux.Lenses.Coinbase.FeesLens.focus()
```

### Trading

```elixir
# Market buy $100 of BTC
{:ok, %{success: true, order_id: id}} = Lux.Prisms.Coinbase.CreateOrder.handler(%{
  product_id: "BTC-USD",
  side: "BUY",
  order_configuration: %{
    market_market_ioc: %{quote_size: "100.00"}
  }
}, %{agent: %{name: "MyAgent"}})

# Limit buy order
{:ok, _} = Lux.Prisms.Coinbase.CreateOrder.handler(%{
  product_id: "BTC-USD",
  side: "BUY",
  order_configuration: %{
    limit_limit_gtc: %{
      base_size: "0.001",
      limit_price: "40000.00",
      post_only: true
    }
  }
}, %{agent: %{name: "MyAgent"}})

# Cancel orders
{:ok, %{results: results}} = Lux.Prisms.Coinbase.CancelOrders.handler(%{
  order_ids: ["order-id-1", "order-id-2"]
}, %{agent: %{name: "MyAgent"}})

# Get order details
{:ok, order} = Lux.Prisms.Coinbase.GetOrder.handler(%{
  order_id: "order-id-123"
}, %{agent: %{name: "MyAgent"}})
```

### WebSocket Streaming

```elixir
# Start streaming ticker data
{:ok, pid} = Lux.Integrations.Coinbase.WebSocket.start_link(
  channels: ["ticker", "heartbeats"],
  product_ids: ["BTC-USD", "ETH-USD"],
  handler: fn message ->
    IO.inspect(message, label: "Coinbase WS")
  end
)

# Subscribe to additional channels
Lux.Integrations.Coinbase.WebSocket.subscribe(pid, ["level2"], ["SOL-USD"])

# Check connection status
status = Lux.Integrations.Coinbase.WebSocket.status(pid)
```

## Supported Order Types

| Type | Key | Description |
|------|-----|-------------|
| Market | `market_market_ioc` | Immediate execution at market price |
| Limit GTC | `limit_limit_gtc` | Good till cancelled limit order |
| Limit GTD | `limit_limit_gtd` | Good till date limit order |
| Stop-Limit GTC | `stop_limit_stop_limit_gtc` | Stop-limit, good till cancelled |
| Stop-Limit GTD | `stop_limit_stop_limit_gtd` | Stop-limit, good till date |

## WebSocket Channels

| Channel | Description | Auth Required |
|---------|-------------|---------------|
| `heartbeats` | Periodic heartbeat messages | No |
| `candles` | Real-time candle data | No |
| `market_trades` | Real-time market trades | No |
| `status` | Product status updates | No |
| `ticker` | Real-time price ticker | No |
| `ticker_batch` | Batched ticker updates | No |
| `level2` | Level 2 order book data | No |
| `user` | User order updates | Yes |

## Error Handling

All modules return standard `{:ok, result}` / `{:error, reason}` tuples. Common errors:

- `{:error, :invalid_credentials}` — Invalid or expired API key
- `{:error, :forbidden}` — Insufficient API key permissions
- `{:error, {:rate_limited, retry_after_seconds}}` — Rate limit exceeded
- `{:error, {status_code, message}}` — API-specific errors
- `{:error, {:auth_error, reason}}` — JWT generation failure

## Rate Limits

The Coinbase Advanced Trade API enforces rate limits per endpoint. The client includes:
- Automatic retry disabling (to avoid hammering on 429s)
- Retry-After header parsing for rate limit responses
- Built-in error classification for rate limit responses

## Testing

All components are fully tested with mocked HTTP responses using `Req.Test`:

```bash
mix test test/unit/lux/lenses/coinbase/ test/unit/lux/prisms/coinbase/ test/unit/lux/integrations/coinbase/ --include unit
```
