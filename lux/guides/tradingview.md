# TradingView Technical Analysis Integration

Lux provides comprehensive TradingView integration for market analysis,
signal generation, and alert management.

## Overview

The TradingView integration consists of:

### Lenses (Data Retrieval)
- **`Lux.Lenses.TradingView.ChartData`** — OHLCV price data
- **`Lux.Lenses.TradingView.TechnicalRating`** — Technical indicators and ratings

### Prisms (Analysis & Actions)
- **`Lux.Prisms.TradingView.TechnicalAnalysis`** — Multi-timeframe TA
- **`Lux.Prisms.TradingView.SignalGenerator`** — Trading signal generation
- **`Lux.Prisms.TradingView.AlertManager`** — Price and indicator alerts

## Quick Start

### Fetch Technical Ratings

```elixir
# Get daily technical analysis for BTC
{:ok, rating} = Lux.Lenses.TradingView.TechnicalRating.focus(%{
  symbol: "BINANCE:BTCUSDT",
  interval: "D"
})

IO.puts("Recommendation: #{rating.recommendation}")
IO.puts("RSI: #{rating.oscillators.indicators.rsi}")
```

### Multi-Timeframe Analysis

```elixir
# Analyze across 1h, 4h, and daily
{:ok, analysis} = Lux.Prisms.TradingView.TechnicalAnalysis.handler(%{
  "symbol" => "BINANCE:ETHUSDT",
  "timeframes" => ["60", "240", "D"],
  "strategy" => "trend_following"
}, nil)

IO.puts("Signal: #{analysis.signal}")
IO.puts("Confidence: #{analysis.confidence}")
IO.puts("Alignment: #{analysis.alignment}")
IO.puts(analysis.summary)
```

### Generate Trading Signals

```elixir
# Get complete trading signal with entry/exit levels
{:ok, signal} = Lux.Prisms.TradingView.SignalGenerator.handler(%{
  "symbol" => "BINANCE:BTCUSDT",
  "risk_pct" => 2.0,
  "timeframe" => "60"
}, nil)

case signal.direction do
  :long ->
    IO.puts("LONG Entry: $#{signal.entry.low} - $#{signal.entry.high}")
    IO.puts("Stop Loss: $#{signal.stop_loss}")
    IO.puts("Take Profit: #{inspect(signal.take_profit)}")
    IO.puts("Risk/Reward: #{signal.risk_reward}")
  :short ->
    IO.puts("SHORT signal generated")
  :neutral ->
    IO.puts("No clear signal - stay out")
end
```

### Manage Alerts

```elixir
# Create a price alert
{:ok, alert} = Lux.Prisms.TradingView.AlertManager.handler(%{
  "action" => "create",
  "symbol" => "BINANCE:BTCUSDT",
  "type" => "price_above",
  "value" => 100000.0,
  "message" => "BTC broke $100K!"
}, nil)

# Check alerts against current price
{:ok, result} = Lux.Prisms.TradingView.AlertManager.handler(%{
  "action" => "check",
  "symbol" => "BINANCE:BTCUSDT",
  "alerts" => [alert]
}, nil)
```

## Supported Symbols

Use the `EXCHANGE:PAIR` format:

| Exchange | Example |
|----------|---------|
| Binance | `BINANCE:BTCUSDT` |
| Coinbase | `COINBASE:BTCUSD` |
| Kraken | `KRAKEN:XBTUSD` |
| Bybit | `BYBIT:BTCUSDT` |
| NYSE | `NYSE:AAPL` |
| NASDAQ | `NASDAQ:TSLA` |

## Timeframes

| Code | Period |
|------|--------|
| `1` | 1 minute |
| `5` | 5 minutes |
| `15` | 15 minutes |
| `30` | 30 minutes |
| `60` | 1 hour |
| `120` | 2 hours |
| `240` | 4 hours |
| `D` | Daily |
| `W` | Weekly |
| `M` | Monthly |

## Analysis Strategies

### Trend Following
Boosts signals when higher timeframes confirm the direction.
Best for: Trending markets, swing trading.

### Mean Reversion
Reverses signals at extremes (overbought/oversold).
Best for: Range-bound markets, counter-trend trading.

### Momentum
Emphasizes oscillator strength and momentum indicators.
Best for: Breakout detection, momentum trading.

### Comprehensive (Default)
Balanced analysis using all indicators without bias.
Best for: General purpose, uncertain market conditions.

## Technical Indicators

### Oscillators
RSI, Stochastic K/D, CCI, ADX (+DI/-DI), Awesome Oscillator,
Momentum, MACD (value + signal), Williams %R, Bull/Bear Power,
Ultimate Oscillator, Stochastic RSI

### Moving Averages
SMA/EMA: 10, 20, 30, 50, 100, 200 periods
Ichimoku Baseline, VWMA, Hull MA(9)

## Agent Integration

Use these tools in your Lux agents:

```elixir
defmodule MyAgent do
  use Lux.Agent,
    name: "Trading Analyst",
    goal: "Provide technical analysis and trading signals",
    tools: [
      Lux.Lenses.TradingView.ChartData,
      Lux.Lenses.TradingView.TechnicalRating,
      Lux.Prisms.TradingView.TechnicalAnalysis,
      Lux.Prisms.TradingView.SignalGenerator,
      Lux.Prisms.TradingView.AlertManager
    ]
end
```
