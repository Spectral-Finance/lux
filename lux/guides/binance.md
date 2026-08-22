# Binance Exchange Integration Guide

This module provides a robust, native integration with the Binance Spot and USD-M Futures APIs for `Lux`.

## REST API Client

The `Lux.Binance.Client` provides an interface to execute signed and unsigned REST requests. It is built on top of `Req` and features an automatic exponential backoff rate limiter.

### Examples

```elixir
# Public Spot ticker price request
{:ok, %{"symbol" => "BTCUSDT", "price" => "95120.50"}} = 
  Lux.Binance.Client.request(:get, :spot, "/api/v3/ticker/price", %{symbol: "BTCUSDT"})

# Signed Spot account request
{:ok, %{"balances" => [...]}} = 
  Lux.Binance.Client.request(:get, :spot, "/api/v3/account", %{}, signed: true)
```

## WebSocket Streaming

`Lux.Binance.WebSocket.Client` manages connections to the Binance WebSocket streams, automatically handling reconnection logic and keep-alives.

`Lux.Binance.WebSocket.UserDataStream` creates and manages the `listenKey` for authenticated private streams (such as execution reports and account updates).

### Examples

```elixir
# Subscribe to public market streams
{:ok, pid} = Lux.Binance.WebSocket.Client.start_link(
  subscriber: self(),
  streams: ["btcusdt@trade", "ethusdt@kline_1m"]
)

# Manage private User Data Streams (automatically connects a WebSocket client)
{:ok, user_data_stream_pid} = Lux.Binance.WebSocket.UserDataStream.start_link(
  market_type: :futures,
  subscriber: self()
)
```

## Rate Limiter Resilience

The `Lux.Binance.RateLimiter` is a globally supervised GenServer that automatically interprets HTTP 429 and 418 responses, parses the `Retry-After` header, and applies a deterministic backoff across all `Lux.Binance.Client` requests to protect your API keys from bans.

## Prisms and Lenses

Higher-level abstractions are provided via Lux Prisms and Lenses:
- `Lux.Prisms.Binance.SpotOrderPrism`
- `Lux.Prisms.Binance.FuturesOrderPrism`
- `Lux.Prisms.Binance.SpotAccountPrism`
- ... and more.
