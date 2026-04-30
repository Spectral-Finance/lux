# Hyperliquid Integration Module

## Overview

This module provides comprehensive Hyperliquid perpetual trading integration for the Spectral Finance lux platform, implementing the Lens/Prism/Beam architecture pattern for position management, risk control, and trading operations.

## Architecture

The integration follows the Lens/Prism/Beam pattern:

- **Lenses**: Data collection modules that fetch and process market data, positions, and risk metrics
- **Prisms**: Data transformation modules that calculate leverage, margin allocation, PnL, and protection strategies
- **Beams**: Pipeline orchestration modules that coordinate the full trading workflow

## Components

### Lenses

#### Position Tracker Lens
**Module**: `Lux.Lenses.Hyperliquid.PositionTrackerLens`

Tracks open positions, PnL, and margin usage across all perpetual markets.

```elixir
Lux.Lenses.Hyperliquid.PositionTrackerLens.focus(%{
  address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5"
})
```

**Returns**:
- List of all open positions with size, entry price, mark price, unrealized PnL
- Position summary with total PnL, margin usage, and utilization ratio
- Side determination (long/short) for each position

#### Risk Monitoring Lens
**Module**: `Lux.Lenses.Hyperliquid.RiskMonitoringLens`

Monitors portfolio risk metrics including exposure, concentration, and overall risk score.

```elixir
Lux.Lenses.Hyperliquid.RiskMonitoringLens.focus(%{
  address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5",
  lookback_hours: 24
})
```

**Returns**:
- Gross and net exposure metrics
- Portfolio concentration (Herfindahl index)
- Risk score (0-1 scale)
- Risk alerts for high exposure or concentration

#### Liquidation Monitor Lens
**Module**: `Lux.Lenses.Hyperliquid.LiquidationMonitorLens`

Monitors liquidation prices and margin health for all positions.

```elixir
Lux.Lenses.Hyperliquid.LiquidationMonitorLens.focus(%{
  address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5"
})
```

**Returns**:
- Distance to liquidation for each position
- Warning levels (safe, caution, warning, danger)
- Overall margin health
- Liquidation alerts for at-risk positions

#### Market Data Lens
**Module**: `Lux.Lenses.Hyperliquid.MarketDataLens`

Fetches real-time market data for all perpetual markets.

```elixir
Lux.Lenses.Hyperliquid.MarketDataLens.focus(%{})
```

**Returns**:
- Mark prices, mid prices, and oracle prices
- Funding rates and open interest
- Day volume and price statistics
- Order book impact prices

### Prisms

#### Leverage Manager Prism
**Module**: `Lux.Prisms.Hyperliquid.LeverageManagerPrism`

Calculates and manages optimal leverage settings based on risk tolerance.

```elixir
Lux.Prisms.Hyperliquid.LeverageManagerPrism.run(%{
  portfolio: portfolio_state,
  proposed_position: %{coin: "ETH", sz: 0.5, limit_px: 2800.0},
  market_data: market_prices,
  risk_tolerance: "moderate"  # "conservative", "moderate", or "aggressive"
})
```

**Returns**:
- Recommended leverage level
- Maximum safe leverage based on risk tolerance
- Current and projected leverage
- Risk assessment (very_low, low, moderate, high, critical)

**Risk Tolerance Levels**:
- Conservative: Max 3x leverage
- Moderate: Max 5x leverage
- Aggressive: Max 10x leverage

#### Margin Allocator Prism
**Module**: `Lux.Prisms.Hyperliquid.MarginAllocatorPrism`

Allocates margin across positions efficiently.

```elixir
Lux.Prisms.Hyperliquid.MarginAllocatorPrism.run(%{
  portfolio: portfolio_state,
  new_position: %{coin: "SOL", sz: 10, limit_px: 150.0},
  allocation_strategy: "risk_adjusted"  # "equal_weight", "risk_adjusted", "performance_based"
})
```

**Returns**:
- Current margin allocations by asset
- Recommended allocation for new position
- Allocation status (approved, partial, rejected)
- Remaining margin and utilization ratio

#### Liquidation Protection Prism
**Module**: `Lux.Prisms.Hyperliquid.LiquidationProtectionPrism`

Implements liquidation prevention strategies.

```elixir
Lux.Prisms.Hyperliquid.LiquidationProtectionPrism.run(%{
  portfolio: portfolio_state,
  market_data: market_prices,
  protection_strategy: "set_stop_loss",  # "add_margin", "reduce_position", "set_stop_loss", "auto_deleverage"
  safety_buffer: 0.15
})
```

**Returns**:
- Actions taken for each at-risk position
- Protection details (stop loss price, reduction size, etc.)
- Summary of positions at risk and actions taken

#### PnL Analyzer Prism
**Module**: `Lux.Prisms.Hyperliquid.PnlAnalyzerPrism`

Analyzes PnL and generates performance reports.

```elixir
Lux.Prisms.Hyperliquid.PnlAnalyzerPrism.run(%{
  portfolio: portfolio_state,
  market_data: market_prices,
  analysis_period: "24h"  # "1h", "4h", "24h", "7d", "30d"
})
```

**Returns**:
- Unrealized PnL by asset and total
- Performance metrics (win rate, profit factor, Sharpe ratio, max drawdown)
- Position-level analysis with PnL and direction
- Portfolio summary

### Beam

#### Perpetual Trading Engine
**Module**: `Lux.Beams.Hyperliquid.PerpetualTradingEngine`

Orchestrates the full perpetual trading workflow with integrated risk management.

```elixir
Lux.Beams.Hyperliquid.PerpetualTradingEngine.run(%{
  address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5",
  trade: %{
    coin: "ETH",
    is_buy: true,
    sz: 0.5,
    limit_px: 2800.0,
    order_type: %{limit: %{tif: "Gtc"}},
    reduce_only: false
  },
  risk_params: %{
    max_leverage: 5.0,
    stop_loss_pct: 0.05,
    take_profit_pct: 0.10,
    max_position_size_pct: 0.20
  }
})
```

**Workflow**:
1. Fetches current portfolio state
2. Gets current market data
3. Calculates leverage recommendations
4. Validates margin allocation
5. Performs risk assessment
6. Executes trade if all checks pass
7. Sets up liquidation protection
8. Analyzes resulting PnL

## Configuration

The modules require the following configuration in your application environment:

```elixir
config :lux, :accounts,
  hyperliquid_private_key: "your_private_key",
  hyperliquid_address: "0x...",
  hyperliquid_api_url: "https://api.hyperliquid.xyz"
```

## Usage Examples

### Basic Position Tracking

```elixir
# Get all open positions
{:ok, result} = Lux.Lenses.Hyperliquid.PositionTrackerLens.focus(%{
  address: "0xYourAddress"
})

IO.inspect(result.positions)
IO.inspect(result.summary)
```

### Risk Assessment Before Trading

```elixir
# Check risk before placing a trade
{:ok, risk} = Lux.Lenses.Hyperliquid.RiskMonitoringLens.focus(%{
  address: "0xYourAddress"
})

if risk.risk_score < 0.7 do
  # Proceed with trade
end
```

### Liquidation Monitoring

```elixir
# Monitor liquidation risk
{:ok, monitor} = Lux.Lenses.Hyperliquid.LiquidationMonitorLens.focus(%{
  address: "0xYourAddress"
})

# Check for dangerous positions
dangerous = Enum.filter(monitor.positions, &(&1.warning_level == "danger"))
Enum.each(dangerous, &IO.puts("Position at risk: #{&1.coin}"))
```

### Full Trading Workflow

```elixir
# Execute a trade with full risk management
{:ok, result} = Lux.Beams.Hyperliquid.PerpetualTradingEngine.run(%{
  address: "0xYourAddress",
  trade: %{
    coin: "ETH",
    is_buy: true,
    sz: 0.5,
    limit_px: 2800.0,
    order_type: %{limit: %{tif: "Gtc"}}
  },
  risk_params: %{
    max_leverage: 5.0,
    stop_loss_pct: 0.05
  }
})
```

## Testing

Run the test suite:

```bash
# Unit tests
mix test test/unit/lux/lenses/hyperliquid/
mix test test/unit/lux/prisms/hyperliquid/

# Integration tests
mix test test/integration/hyperliquid/ --only integration
```

## Risk Controls

The integration implements multiple layers of risk control:

1. **Leverage Limits**: Enforced by risk tolerance level (conservative/moderate/aggressive)
2. **Position Size Limits**: Maximum allocation percentage per position
3. **Concentration Limits**: Herfindahl index monitoring for portfolio diversification
4. **Liquidation Protection**: Automatic stop-loss and position reduction
5. **Margin Monitoring**: Real-time margin health tracking

## Error Handling

All modules follow consistent error handling patterns:

```elixir
case module.function(input) do
  {:ok, result} ->
    # Handle success
  {:error, reason} ->
    # Handle error
end
```

## Integration with Existing Modules

This integration builds on the existing Hyperliquid modules:

- `HyperliquidExecuteOrderPrism` - Order execution
- `HyperliquidUserStatePrism` - Portfolio state fetching
- `HyperliquidOpenOrdersPrism` - Open orders tracking
- `HyperliquidCancelOrderPrism` - Order cancellation
- `HyperliquidRiskAssessmentPrism` - Basic risk assessment
- `HyperliquidTokenInfoPrism` - Token price data
- `TradeRiskManagementBeam` - Basic trade risk management

## License

This module is part of the Spectral Finance lux project.
