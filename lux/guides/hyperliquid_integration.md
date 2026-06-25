# Hyperliquid Exchange Integration Guide

## Overview

Lux provides a comprehensive Hyperliquid exchange integration for perpetual trading. This guide covers all available prisms, the risk management beam, and usage examples.

## Architecture

The Hyperliquid integration consists of:

1. **Prisms** - Individual trading operations
2. **Beams** - Orchestrated workflows combining multiple prisms
3. **Risk Management** - Automated trade evaluation and execution

## Prism Reference

### HyperliquidExecuteOrderPrism

Executes orders on the Hyperliquid exchange.

**Supported order types:**
- **Limit orders** - Standard limit orders with configurable time-in-force
- **Trigger orders** - Stop-loss and take-profit orders
- **Slippage-controlled orders** - Market-like execution with price protection

**Parameters:**
```elixir
%{
  coin: "ETH",
  is_buy: true,
  sz: 0.1,
  limit_px: 2800.0,
  order_type: %{limit: %{tif: "Gtc"}},  # or %{trigger: %{...}} or %{slippage: 0.5}
  reduce_only: false,
  vault_address: "0x...",           # Optional vault address
  tp_limit: %{limit_px: 3000.0},    # Optional take-profit
  sl_limit: %{limit_px: 2600.0}     # Optional stop-loss
}
```

### HyperliquidCancelOrderPrism

Cancels orders on the Hyperliquid exchange.

**Supported actions:**
- `cancel` - Cancel a specific order by ID
- `cancel_all_for_coin` - Cancel all orders for a specific coin
- `cancel_all` - Cancel all open orders

**Parameters:**
```elixir
%{
  action: "cancel_all_for_coin",
  coin: "ETH"
}
```

### HyperliquidOpenOrdersPrism

Fetches open orders from the Hyperliquid exchange.

**Parameters:**
```elixir
%{
  address: "0x..."
}
```

### HyperliquidTokenInfoPrism

Fetches token price data from the Hyperliquid API.

**Parameters:** None required

**Returns:**
```elixir
%{
  prices: %{
    "ETH" => %{
      markPx: "...",
      funding: "...",
      midPx: "...",
      ...
    }
  }
}
```

### HyperliquidUserStatePrism

Fetches user state information from the Hyperliquid exchange.

**Parameters:**
```elixir
%{
  address: "0x...",
  vault_address: "0x..."  # Optional
}
```

### HyperliquidPositionManagementPrism

Manages existing positions on the Hyperliquid exchange.

**Supported actions:**
- `close` - Close entire position
- `partial_close` - Close a percentage of position
- `scale_in` - Add to existing position
- `scale_out` - Reduce existing position
- `trailing_stop` - Set trailing stop loss
- `adjust_leverage` - Adjust leverage (informational)

**Parameters:**
```elixir
# Close entire position
%{action: "close", coin: "ETH", address: "0x..."}

# Partial close (50%)
%{action: "partial_close", coin: "ETH", close_percentage: 0.5, address: "0x..."}

# Trailing stop (5%)
%{action: "trailing_stop", coin: "ETH", trail_percent: 5.0, address: "0x..."}

# Scale in
%{action: "scale_in", coin: "ETH", sz: 0.1, is_buy: true, address: "0x..."}
```

### HyperliquidMarginManagementPrism

Manages margin on the Hyperliquid exchange.

**Supported actions:**
- `check_margin_health` - Assess overall margin health
- `transfer_margin` - Allocate margin to a position
- `get_margin_allocation` - View margin distribution

**Parameters:**
```elixir
# Check margin health
%{action: "check_margin_health", address: "0x..."}

# Transfer margin
%{action: "transfer_margin", coin: "ETH", margin_usd: 1000.0, address: "0x..."}

# Get allocation
%{action: "get_margin_allocation", address: "0x..."}
```

### HyperliquidRiskAssessmentPrism

Calculates risk metrics for proposed trades.

**Parameters:**
```elixir
%{
  portfolio: %{...},           # From HyperliquidUserStatePrism
  market_data: %{...},         # From HyperliquidTokenInfoPrism
  proposed_trade: %{
    coin: "ETH",
    sz: 0.1,
    limit_px: 2800.0,
    is_buy: true
  }
}
```

**Returns risk metrics:**
```elixir
%{
  position_size_ratio: 0.15,
  leverage: 2.0,
  portfolio_concentration: 0.25,
  liquidation_risk: 0.05,
  unrealized_pnl: 0.1
}
```

## Beam: TradeRiskManagementBeam

The `TradeRiskManagementBeam` orchestrates the full trading pipeline:

1. Fetches current portfolio state
2. Gets market prices
3. Calculates risk metrics
4. Evaluates against risk thresholds
5. Executes trade if risk is acceptable

**Risk thresholds:**
- Position size ratio: <= 20% of portfolio
- Leverage: <= 5x
- Portfolio concentration: <= 40%
- Liquidation risk: <= 10% distance

**Usage:**
```elixir
Lux.Beams.Hyperliquid.TradeRiskManagementBeam.run(%{
  address: "0x...",
  trade: %{
    coin: "ETH",
    is_buy: true,
    sz: 0.1,
    limit_px: 2800.0,
    order_type: %{limit: %{tif: "Gtc"}},
    reduce_only: false
  }
})
```

## Configuration

Required environment variables:

```bash
HYPERLIQUID_PRIVATE_KEY=<your_private_key>
HYPERLIQUID_ADDRESS=<your_address>          # Optional, derived from key
HYPERLIQUID_API_URL=https://api.hyperliquid.xyz
```

Configuration is loaded via `Lux.Config`:

```elixir
Lux.Config.hyperliquid_account_key()    # Private key
Lux.Config.hyperliquid_account_address() # Account address
Lux.Config.hyperliquid_api_url()         # API endpoint
```

## Testing

### Unit Tests
Validate prism schemas, metadata, and handler signatures:

```bash
mix test test/unit/hyperliquid/prisms_test.exs
```

### Integration Tests
Require actual Hyperliquid credentials:

```bash
HYPERLIQUID_PRIVATE_KEY=xxx HYPERLIQUID_ADDRESS=xxx mix test test/integration/hyperliquid/trading_operations_test.exs
```

## Python Dependencies

The integration relies on Python packages:
- `hyperliquid` - Official Hyperliquid Python SDK
- `hyperliquid_utils` - Lux utility package (in `priv/python/hyperliquid_utils/`)

The `setup()` function initializes the connection:

```python
from hyperliquid_utils.setup import setup
address, info, exchange = setup(private_key, address, api_url, skip_ws=True)
```

## Security Considerations

1. **Private key storage**: Never commit private keys to version control
2. **Reduce-only orders**: Use `reduce_only: true` when closing positions
3. **Risk limits**: The beam enforces position size and leverage limits
4. **Vault addresses**: Use vault addresses for delegated trading
5. **API rate limits**: Hyperliquid has rate limits; implement backoff if needed
