# Coinbase Exchange Trading Agent

A simple agent demonstrating Coinbase Exchange integration for automated trading.

## Overview

This agent showcases how to use the Coinbase prisms for:

1. Market data monitoring
2. Order placement and management
3. Portfolio tracking
4. Risk management with stop-loss orders

## Configuration

Ensure your Coinbase API credentials are configured:

```elixir
# config/config.exs
config :lux, :api_keys,
  coinbase_api_key: System.get_env("COINBASE_API_KEY"),
  coinbase_api_secret: System.get_env("COINBASE_API_SECRET"),
  coinbase_api_passphrase: System.get_env("COINBASE_API_PASSPHRASE")
```

## Usage

```elixir
# Start the agent
{:ok, agent} = CoinbaseTradingAgent.start_link(%{
  product_id: "BTC-USD",
  strategy: :simple_dca
})

# Check status
CoinbaseTradingAgent.get_status(agent)

# Stop the agent
CoinbaseTradingAgent.stop(agent)
```

## Strategy Examples

### Simple DCA (Dollar Cost Averaging)

Buy a fixed amount at regular intervals:

```elixir
CoinbaseTradingAgent.start_link(%{
  product_id: "BTC-USD",
  strategy: :simple_dca,
  interval_hours: 24,
  amount_usd: 100.00
})
```

### Stop-Loss Protection

Protect positions with automatic stop-loss:

```elixir
CoinbaseTradingAgent.start_link(%{
  product_id: "ETH-USD",
  strategy: :stop_loss,
  stop_loss_percent: 5.0  # 5% below current price
})
```

### Market Making

Simple market making strategy:

```elixir
CoinbaseTradingAgent.start_link(%{
  product_id: "BTC-USD",
  strategy: :market_making,
  spread_percent: 0.1,
  order_size: 0.01
})
```

## Warning

This is a demonstration agent. Always test thoroughly in sandbox mode before using real funds.
Implement proper risk management and never trade more than you can afford to lose.