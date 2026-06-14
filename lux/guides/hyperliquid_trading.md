# Hyperliquid Perpetual Trading Integration

## Overview

This integration provides a complete perpetual trading interface with Hyperliquid DEX, including position management, leverage control, risk monitoring, PnL tracking, and margin management.

## Prisms

### HyperliquidExecuteOrderPrism
Executes limit and trigger orders on Hyperliquid.

```elixir
Lux.Prisms.Hyperliquid.HyperliquidExecuteOrderPrism.run(%{
  coin: "ETH",
  is_buy: true,
  sz: 0.1,
  limit_px: 2800.0,
  order_type: %{limit: %{tif: "Gtc"}},
  reduce_only: false
})
```

### HyperliquidCancelOrderPrism
Cancels an open order by coin and order ID.

```elixir
Lux.Prisms.Hyperliquid.HyperliquidCancelOrderPrism.run(%{
  coin: "ETH",
  order_id: 123456
})
```

### HyperliquidOpenOrdersPrism
Fetches all open orders for an address.

```elixir
Lux.Prisms.Hyperliquid.HyperliquidOpenOrdersPrism.run(%{
  address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5"
})
```

### HyperliquidUserStatePrism
Fetches full user state including positions and margin summary.

```elixir
Lux.Prisms.Hyperliquid.HyperliquidUserStatePrism.run(%{
  address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5"
})
```

### HyperliquidLeveragePrism
Sets leverage for a trading pair.

```elixir
Lux.Prisms.Hyperliquid.HyperliquidLeveragePrism.run(%{
  coin: "ETH",
  leverage: 5,
  is_cross: true
})
```

### HyperliquidMarginPrism
Adds or removes isolated margin from a position.

```elixir
Lux.Prisms.Hyperliquid.HyperliquidMarginPrism.run(%{
  coin: "ETH",
  amount: 100.0,
  is_buy: true
})
```

### HyperliquidPnlPrism
Fetches unrealized PnL and position details for all open positions.

```elixir
Lux.Prisms.Hyperliquid.HyperliquidPnlPrism.run(%{
  address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5"
})
```

### HyperliquidLiquidationPrism
Monitors liquidation risk across all open positions.

```elixir
Lux.Prisms.Hyperliquid.HyperliquidLiquidationPrism.run(%{
  address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5",
  risk_threshold: 0.1
})
```

### HyperliquidRiskAssessmentPrism
Calculates risk metrics for a proposed trade.

```elixir
Lux.Prisms.Hyperliquid.HyperliquidRiskAssessmentPrism.run(%{
  portfolio: portfolio,
  market_data: market_data,
  proposed_trade: %{coin: "ETH", sz: 0.1, limit_px: 2800.0, is_buy: true}
})
```

### HyperliquidTokenInfoPrism
Fetches current market data and prices for all tokens.

```elixir
Lux.Prisms.Hyperliquid.HyperliquidTokenInfoPrism.run(%{})
```

## Configuration

Add to your config:

```elixir
config :lux,
  hyperliquid_private_key: System.get_env("HYPERLIQUID_PRIVATE_KEY"),
  hyperliquid_account_address: System.get_env("HYPERLIQUID_ACCOUNT_ADDRESS"),
  hyperliquid_api_url: System.get_env("HYPERLIQUID_API_URL")
```

## Environment Variables

```
HYPERLIQUID_PRIVATE_KEY=your_ethereum_private_key
HYPERLIQUID_ACCOUNT_ADDRESS=your_ethereum_address
HYPERLIQUID_API_URL=https://api.hyperliquid.xyz
```

## Risk Management

The integration includes built-in risk controls:
- Position size ratio monitoring
- Leverage tracking
- Portfolio concentration limits
- Liquidation price monitoring with configurable thresholds
- Unrealized PnL tracking
