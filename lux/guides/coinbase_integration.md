# Coinbase Exchange Integration

This document describes the Coinbase Exchange integration for Lux, providing spot trading capabilities, market data access, and portfolio management.

## Overview

The Coinbase Exchange integration provides:

- **REST API Integration** - Full access to Coinbase Exchange REST API
- **WebSocket Support** - Real-time market data and order updates
- **Order Management** - Place, cancel, and track orders
- **Market Data** - Ticker, order book, trades, and candlestick data
- **Account Management** - View balances and account information
- **Portfolio Tracking** - Monitor positions and holdings

## Configuration

Add the following to your Lux configuration:

```elixir
config :lux, :api_keys,
  coinbase_api_key: "your_api_key",
  coinbase_api_secret: "your_base64_encoded_secret",
  coinbase_api_passphrase: "your_passphrase"

config :lux, :accounts,
  coinbase_api_url: "https://api.exchange.coinbase.com",
  coinbase_ws_url: "wss://ws-feed.exchange.coinbase.com"
```

### Getting API Credentials

1. Log in to [Coinbase Exchange](https://exchange.coinbase.com)
2. Navigate to Settings > API
3. Create a new API key with appropriate permissions:
   - **View** - Required for reading account and order data
   - **Trade** - Required for placing and canceling orders
   - **Transfer** - Optional, for withdrawal capabilities
4. Save the API Key, Secret, and Passphrase

### Sandbox Environment

For testing, use the sandbox environment:

```elixir
config :lux, :accounts,
  coinbase_api_url: "https://api-public.sandbox.exchange.coinbase.com",
  coinbase_ws_url: "wss://ws-feed-public.sandbox.exchange.coinbase.com"
```

## Prisms

### Order Management

#### CoinbaseExecuteOrderPrism

Execute orders on Coinbase Exchange.

```elixir
# Limit order
{:ok, result} = Lux.Prisms.Coinbase.CoinbaseExecuteOrderPrism.run(%{
  product_id: "BTC-USD",
  side: "buy",
  order_type: "limit",
  price: "50000.00",
  size: "0.01"
})

# Market order
{:ok, result} = Lux.Prisms.Coinbase.CoinbaseExecuteOrderPrism.run(%{
  product_id: "ETH-USD",
  side: "sell",
  order_type: "market",
  funds: "1000.00"
})

# Stop-loss order
{:ok, result} = Lux.Prisms.Coinbase.CoinbaseExecuteOrderPrism.run(%{
  product_id: "BTC-USD",
  side: "sell",
  order_type: "stop",
  stop_price: "48000.00",
  size: "0.1"
})
```

#### CoinbaseCancelOrderPrism

Cancel orders on Coinbase Exchange.

```elixir
# Cancel specific order
{:ok, result} = Lux.Prisms.Coinbase.CoinbaseCancelOrderPrism.run(%{
  order_id: "order_id_here"
})

# Cancel all orders for a product
{:ok, result} = Lux.Prisms.Coinbase.CoinbaseCancelOrderPrism.run(%{
  cancel_all: true,
  product_id: "BTC-USD"
})

# Cancel all orders
{:ok, result} = Lux.Prisms.Coinbase.CoinbaseCancelOrderPrism.run(%{
  cancel_all: true
})
```

#### CoinbaseOpenOrdersPrism

Fetch open orders.

```elixir
# Get all open orders
{:ok, result} = Lux.Prisms.Coinbase.CoinbaseOpenOrdersPrism.run(%{})

# Get orders for specific product
{:ok, result} = Lux.Prisms.Coinbase.CoinbaseOpenOrdersPrism.run(%{
  product_id: "BTC-USD"
})
```

### Account Management

#### CoinbaseAccountPrism

View account balances and holdings.

```elixir
# Get all accounts
{:ok, result} = Lux.Prisms.Coinbase.CoinbaseAccountPrism.run(%{})

# Get specific account
{:ok, result} = Lux.Prisms.Coinbase.CoinbaseAccountPrism.run(%{
  account_id: "account_id_here"
})

# Get account holds
{:ok, result} = Lux.Prisms.Coinbase.CoinbaseAccountPrism.run(%{
  account_id: "account_id_here",
  get_holds: true
})
```

#### CoinbaseFeesPrism

Get current fee rates.

```elixir
{:ok, result} = Lux.Prisms.Coinbase.CoinbaseFeesPrism.run(%{})
# => %{maker_fee_rate: "0.005", taker_fee_rate: "0.005", usd_volume: "10000.00"}
```

### Market Data

#### CoinbaseMarketDataPrism

Fetch real-time and historical market data.

```elixir
# Get ticker
{:ok, result} = Lux.Prisms.Coinbase.CoinbaseMarketDataPrism.run(%{
  product_id: "BTC-USD",
  data_type: "ticker"
})

# Get order book
{:ok, result} = Lux.Prisms.Coinbase.CoinbaseMarketDataPrism.run(%{
  product_id: "BTC-USD",
  data_type: "orderbook",
  level: 2
})

# Get recent trades
{:ok, result} = Lux.Prisms.Coinbase.CoinbaseMarketDataPrism.run(%{
  product_id: "BTC-USD",
  data_type: "trades"
})

# Get historical candles
{:ok, result} = Lux.Prisms.Coinbase.CoinbaseMarketDataPrism.run(%{
  product_id: "BTC-USD",
  data_type: "candles",
  granularity: 3600  # 1 hour candles
})
```

#### CoinbaseProductsPrism

List available trading products.

```elixir
# Get all products
{:ok, result} = Lux.Prisms.Coinbase.CoinbaseProductsPrism.run(%{})

# Get specific product
{:ok, result} = Lux.Prisms.Coinbase.CoinbaseProductsPrism.run(%{
  product_id: "BTC-USD"
})
```

### WebSocket Integration

#### CoinbaseWebSocketPrism

Subscribe to real-time data feeds.

```elixir
# Subscribe to ticker updates
{:ok, result} = Lux.Prisms.Coinbase.CoinbaseWebSocketPrism.run(%{
  action: "subscribe",
  channels: ["ticker"],
  product_ids: ["BTC-USD", "ETH-USD"]
})

# Subscribe to order updates (authenticated)
{:ok, result} = Lux.Prisms.Coinbase.CoinbaseWebSocketPrism.run(%{
  action: "subscribe",
  channels: ["user"],
  product_ids: ["BTC-USD"],
  authenticate: true
})

# Get WebSocket status
{:ok, result} = Lux.Prisms.Coinbase.CoinbaseWebSocketPrism.run(%{
  action: "get_status"
})
```

Available channels:
- `heartbeat` - Connection heartbeat
- `ticker` - Ticker updates
- `level2` - Level 2 order book
- `matches` - Trade matches
- `user` - User order updates (authenticated)
- `full` - Full order book updates

## Rate Limits

Coinbase Exchange API has the following rate limits:

- **Public endpoints**: 10 requests/second, 1000 requests/hour
- **Private endpoints**: 15 requests/second, 5000 requests/hour

The integration handles rate limiting automatically.

## Error Handling

All prisms return standardized results:

```elixir
# Success
{:ok, %{status: "success", data: ...}}

# Error
{:error, "Error message"}
```

Common errors:
- `"Coinbase API key is not configured"` - Missing API key
- `"Coinbase API secret is not configured"` - Missing API secret
- `"Coinbase API passphrase is not configured"` - Missing passphrase
- `"API error: 401 - ..."` - Authentication failure
- `"API error: 429 - ..."` - Rate limit exceeded

## Testing

Run tests:

```bash
# Unit tests
mix test test/prisms/coinbase/

# Integration tests (requires API credentials)
mix test --include integration test/prisms/coinbase/

# Python tests
cd lux/priv/python
pytest tests/test_coinbase_utils.py
```

## Examples

### Simple Trading Bot

```elixir
defmodule MyTradingBot do
  alias Lux.Prisms.Coinbase.{
    CoinbaseMarketDataPrism,
    CoinbaseExecuteOrderPrism,
    CoinbaseOpenOrdersPrism
  }

  def execute_strategy(product_id) do
    # Get current price
    {:ok, %{data: ticker}} = CoinbaseMarketDataPrism.run(%{
      product_id: product_id,
      data_type: "ticker"
    })

    price = String.to_float(ticker["price"])

    # Check existing orders
    {:ok, %{orders: orders}} = CoinbaseOpenOrdersPrism.run(%{
      product_id: product_id
    })

    # Execute strategy logic
    if length(orders) == 0 and price < target_price do
      CoinbaseExecuteOrderPrism.run(%{
        product_id: product_id,
        side: "buy",
        order_type: "limit",
        price: Float.to_string(price * 0.99),
        size: "0.01"
      })
    end
  end
end
```

### Market Data Monitor

```elixir
defmodule MarketMonitor do
  alias Lux.Prisms.Coinbase.CoinbaseWebSocketPrism

  def start do
    {:ok, result} = CoinbaseWebSocketPrism.run(%{
      action: "subscribe",
      channels: ["ticker", "level2"],
      product_ids: ["BTC-USD", "ETH-USD"]
    })

    # Use subscribe_messages to connect to WebSocket
    result.subscribe_messages
  end
end
```

## Security Best Practices

1. **Never commit API credentials** - Use environment variables or secure storage
2. **Use minimal permissions** - Only grant necessary API permissions
3. **Monitor API usage** - Watch for unusual activity
4. **Use sandbox for testing** - Test all strategies in sandbox first
5. **Implement proper error handling** - Handle API failures gracefully

## References

- [Coinbase Exchange API Documentation](https://docs.cdp.coinbase.com/exchange/docs/rest-api.html)
- [Coinbase Exchange WebSocket Documentation](https://docs.cdp.coinbase.com/exchange/docs/websocket-overview.html)
- [Lux Documentation](https://hexdocs.pm/lux)