# Binance Exchange Integration

Lux provides comprehensive integration with the Binance exchange, supporting both spot and futures trading through REST APIs and WebSocket streams.

## Overview

The Binance integration is organized into several components:

| Component | Module | Purpose |
|-----------|--------|---------|
| **Client** | `Lux.Integrations.Binance.Client` | HTTP client for REST API requests |
| **WebSocket** | `Lux.Integrations.Binance.WebSocket` | Real-time market data streams |
| **Rate Limiter** | `Lux.Integrations.Binance.RateLimiter` | API rate limit compliance |
| **Market Data Lens** | `Lux.Lenses.Binance.MarketDataLens` | Read market data (prices, depth, trades) |
| **Account Info Lens** | `Lux.Lenses.Binance.AccountInfoLens` | Read account/portfolio data |
| **Spot Order Prism** | `Lux.Prisms.Binance.SpotOrderPrism` | Place spot orders |
| **Futures Order Prism** | `Lux.Prisms.Binance.FuturesOrderPrism` | Place futures orders |
| **Cancel Order Prism** | `Lux.Prisms.Binance.CancelOrderPrism` | Cancel orders |
| **Futures Leverage Prism** | `Lux.Prisms.Binance.FuturesLeveragePrism` | Manage leverage/margin settings |
| **Spot Trade Beam** | `Lux.Beams.Binance.SpotTradeBeam` | Orchestrated spot trading workflow |
| **Futures Trade Beam** | `Lux.Beams.Binance.FuturesTradeBeam` | Orchestrated futures trading workflow |

## Configuration

Add your Binance API credentials to your application config:

```elixir
# config/config.exs or config/runtime.exs
config :lux, :api_keys,
  binance_api_key: System.get_env("BINANCE_API_KEY"),
  binance_secret_key: System.get_env("BINANCE_SECRET_KEY")
```

> ⚠️ **Security**: Never commit API keys to version control. Use environment variables or a secrets manager.

## Quick Start

### Fetching Market Data

```elixir
# Get current BTC price
{:ok, %{symbol: "BTCUSDT", price: price}} =
  Lux.Lenses.Binance.MarketDataLens.focus(%{
    type: "ticker_price",
    symbol: "BTCUSDT"
  })

# Get 24h statistics
{:ok, stats} =
  Lux.Lenses.Binance.MarketDataLens.focus(%{
    type: "ticker_24h",
    symbol: "ETHUSDT"
  })

# Get order book
{:ok, %{bids: bids, asks: asks}} =
  Lux.Lenses.Binance.MarketDataLens.focus(%{
    type: "depth",
    symbol: "BTCUSDT",
    limit: 10
  })

# Get kline/candlestick data
{:ok, %{klines: klines}} =
  Lux.Lenses.Binance.MarketDataLens.focus(%{
    type: "klines",
    symbol: "BTCUSDT",
    interval: "1h",
    limit: 24
  })
```

### Account Information

```elixir
# Get spot balances
{:ok, %{balances: balances}} =
  Lux.Lenses.Binance.AccountInfoLens.focus(%{
    type: "spot_account"
  })

# Get futures positions
{:ok, %{positions: positions}} =
  Lux.Lenses.Binance.AccountInfoLens.focus(%{
    type: "futures_positions"
  })

# Get open orders
{:ok, %{orders: orders}} =
  Lux.Lenses.Binance.AccountInfoLens.focus(%{
    type: "open_orders",
    symbol: "BTCUSDT"
  })
```

### Placing Spot Orders

```elixir
# Market buy
{:ok, %{status: "success", order: order}} =
  Lux.Prisms.Binance.SpotOrderPrism.run(%{
    symbol: "BTCUSDT",
    side: "BUY",
    type: "MARKET",
    quantity: "0.001"
  })

# Limit sell
{:ok, %{status: "success", order: order}} =
  Lux.Prisms.Binance.SpotOrderPrism.run(%{
    symbol: "BTCUSDT",
    side: "SELL",
    type: "LIMIT",
    quantity: "0.001",
    price: "50000",
    time_in_force: "GTC"
  })
```

### Placing Futures Orders

```elixir
# Set leverage first
{:ok, _} = Lux.Prisms.Binance.FuturesLeveragePrism.run(%{
  action: "set_leverage",
  symbol: "BTCUSDT",
  leverage: 10
})

# Market long
{:ok, %{status: "success", order: order}} =
  Lux.Prisms.Binance.FuturesOrderPrism.run(%{
    symbol: "BTCUSDT",
    side: "BUY",
    type: "MARKET",
    quantity: "0.001"
  })

# Stop-loss
{:ok, _} = Lux.Prisms.Binance.FuturesOrderPrism.run(%{
  symbol: "BTCUSDT",
  side: "SELL",
  type: "STOP_MARKET",
  quantity: "0.001",
  stop_price: "38000",
  reduce_only: true
})
```

### Cancelling Orders

```elixir
# Cancel specific order
{:ok, _} = Lux.Prisms.Binance.CancelOrderPrism.run(%{
  symbol: "BTCUSDT",
  order_id: 123456,
  market: "spot"
})

# Cancel all orders for a symbol
{:ok, _} = Lux.Prisms.Binance.CancelOrderPrism.run(%{
  symbol: "BTCUSDT",
  cancel_all: true,
  market: "spot"
})
```

### Real-Time Market Data (WebSocket)

```elixir
defmodule MyApp.BinanceHandler do
  def handle_message(%{"e" => "trade", "s" => symbol, "p" => price}, _extra) do
    IO.puts("#{symbol}: #{price}")
  end

  def handle_message(_msg, _extra), do: :ok
end

# Start streaming
{:ok, ws} = Lux.Integrations.Binance.WebSocket.start_link(
  streams: ["btcusdt@trade", "ethusdt@trade"],
  handler: {MyApp.BinanceHandler, :handle_message, []}
)

# Subscribe to additional streams
Lux.Integrations.Binance.WebSocket.subscribe(ws, ["solusdt@kline_1m"])

# Unsubscribe
Lux.Integrations.Binance.WebSocket.unsubscribe(ws, ["ethusdt@trade"])
```

### Orchestrated Trading (Beams)

Beams provide multi-step trading workflows with built-in validation:

```elixir
# Spot trade with market data validation
{:ok, result} = Lux.Beams.Binance.SpotTradeBeam.run(%{
  symbol: "BTCUSDT",
  side: "BUY",
  type: "LIMIT",
  quantity: "0.001",
  price: "40000",
  time_in_force: "GTC"
})

# Futures trade with leverage management
{:ok, result} = Lux.Beams.Binance.FuturesTradeBeam.run(%{
  symbol: "BTCUSDT",
  side: "BUY",
  type: "MARKET",
  quantity: "0.001",
  leverage: 10
})
```

## Rate Limiting

The `RateLimiter` module automatically tracks API usage to avoid exceeding Binance's rate limits:

| Limit Type | Spot | Futures |
|-----------|------|---------|
| Request Weight | 1,200/min | 2,400/min |
| Order Rate | 100/10s | 100/10s |
| Daily Orders | 200,000/day | 200,000/day |

```elixir
# Start the rate limiter (add to your supervision tree)
{:ok, _pid} = Lux.Integrations.Binance.RateLimiter.start_link()

# Check before making a request
:ok = Lux.Integrations.Binance.RateLimiter.check_rate(:spot, :request, 5)

# Record the request weight after completion
Lux.Integrations.Binance.RateLimiter.record_request(:spot, :request, 5)
```

## Error Handling

All modules return consistent error tuples:

```elixir
case Lux.Prisms.Binance.SpotOrderPrism.run(order_params) do
  {:ok, %{status: "success", order: order}} ->
    IO.puts("Order #{order.order_id} placed: #{order.status}")

  {:error, "Insufficient balance: " <> _msg} ->
    IO.puts("Not enough funds")

  {:error, "Rate limited" <> _} ->
    Process.sleep(1000)
    # Retry...

  {:error, reason} ->
    IO.puts("Order failed: #{reason}")
end
```

## Architecture

```
┌─────────────────────────────────────────────────┐
│                   Beams (Workflows)              │
│  SpotTradeBeam  │  FuturesTradeBeam             │
├────────────────┬────────────────────────────────┤
│   Lenses       │        Prisms                  │
│  (Read Data)   │     (Take Actions)             │
│  MarketData    │  SpotOrder                     │
│  AccountInfo   │  FuturesOrder                  │
│                │  CancelOrder                   │
│                │  FuturesLeverage               │
├────────────────┴────────────────────────────────┤
│           Client  │  WebSocket  │  RateLimiter  │
│           (REST)  │  (Streams)  │  (Compliance) │
├─────────────────────────────────────────────────┤
│               Binance REST & WS API             │
└─────────────────────────────────────────────────┘
```

## WebSocket Stream Types

| Stream | Description | Example |
|--------|-------------|---------|
| `<symbol>@trade` | Real-time trades | `btcusdt@trade` |
| `<symbol>@kline_<interval>` | Candlestick updates | `btcusdt@kline_1m` |
| `<symbol>@depth<levels>` | Order book updates | `btcusdt@depth10` |
| `<symbol>@ticker` | 24hr ticker | `btcusdt@ticker` |
| `<symbol>@miniTicker` | Mini ticker | `btcusdt@miniTicker` |
| `<symbol>@aggTrade` | Aggregated trades | `btcusdt@aggTrade` |

## Testing

The integration uses `Req.Test` for mocking HTTP requests in tests. See the test files for examples of how to test against the Binance API without making real requests:

```elixir
defmodule MyBinanceTest do
  use UnitAPICase, async: true

  test "my trading test" do
    Req.Test.expect(Lux.Integrations.Binance.Client, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{
        "symbol" => "BTCUSDT",
        "price" => "42000.00"
      }))
    end)

    assert {:ok, _} = Lux.Lenses.Binance.MarketDataLens.focus(
      %{type: "ticker_price", symbol: "BTCUSDT"},
      plug: {Req.Test, Lux.Integrations.Binance.Client}
    )
  end
end
```
