# TradingView Technical Analysis Integration

## Overview

The TradingView integration provides comprehensive technical analysis capabilities for Lux agents, enabling them to analyze market data, generate trading signals, manage alerts, and backtest strategies using TradingView's scanner API.

## Architecture

The integration follows Lux's standard architecture:

- **Lenses** (data retrieval): Fetch technical analysis data from TradingView's scanner API
- **Prisms** (actions): Process indicator data to generate signals, evaluate alerts, and backtest strategies
- **Integration module**: Base configuration with constants, URL builders, and utility functions
- **Client**: HTTP client for TradingView's scanner API

## Quick Start

### Get Technical Analysis Summary

```elixir
alias Lux.Lenses.TradingView.TechnicalAnalysis

# Analyze a US stock
{:ok, analysis} = TechnicalAnalysis.focus(%{
  symbol: "TSLA",
  exchange: "NASDAQ",
  screener: "america",
  interval: "1d"
})

IO.puts("Recommendation: #{analysis.recommendation}")
# => "BUY"
```

### Get Indicator Values

```elixir
alias Lux.Lenses.TradingView.IndicatorValues

# Get all indicators
{:ok, data} = IndicatorValues.focus(%{
  symbol: "BTCUSD",
  exchange: "BINANCE",
  screener: "crypto",
  interval: "4h"
})

IO.puts("RSI: #{data.oscillators.rsi}")
IO.puts("MACD: #{data.oscillators.macd}")
IO.puts("EMA50: #{data.moving_averages.ema50}")

# Get specific indicators only
{:ok, data} = IndicatorValues.focus(%{
  symbol: "TSLA",
  exchange: "NASDAQ",
  indicators: ["RSI", "MACD.macd", "MACD.signal", "EMA50"]
})
```

### Get Chart Data (OHLCV)

```elixir
alias Lux.Lenses.TradingView.ChartData

{:ok, chart} = ChartData.focus(%{
  symbol: "AAPL",
  exchange: "NASDAQ",
  screener: "america",
  interval: "1d"
})

IO.puts("Close: $#{chart.close}")
IO.puts("Volume: #{chart.volume}")
IO.puts("Support (S1): $#{chart.pivot_points.s1}")
IO.puts("Resistance (R1): $#{chart.pivot_points.r1}")
```

### Multi-Timeframe Analysis

```elixir
alias Lux.Lenses.TradingView.MultiTimeframeAnalysis

{:ok, mtf} = MultiTimeframeAnalysis.focus(%{
  symbol: "EURUSD",
  exchange: "FX_IDC",
  screener: "forex",
  intervals: ["15m", "1h", "4h", "1d", "1W"]
})

IO.puts("Consensus: #{mtf.consensus}")
IO.puts("Alignment: #{mtf.alignment * 100}%")

for {tf, data} <- mtf.timeframes do
  IO.puts("  #{tf}: #{data.recommendation}")
end
```

## Prisms (Actions)

### Signal Generator

Generates trading signals with confidence scores from multiple indicators:

```elixir
alias Lux.Prisms.TradingView.SignalGenerator

{:ok, signal} = SignalGenerator.run(%{
  symbol: "TSLA",
  exchange: "NASDAQ",
  screener: "america",
  interval: "1d"
})

IO.puts("Signal: #{signal.signal}")
IO.puts("Confidence: #{signal.confidence}")
IO.puts("Strength: #{signal.strength}")
IO.puts(signal.summary)

# Individual indicator details
IO.puts("RSI Signal: #{signal.indicators.rsi.signal} (#{signal.indicators.rsi.value})")
IO.puts("MACD Signal: #{signal.indicators.macd.signal}")
IO.puts("ADX Trend: #{signal.indicators.adx.trend_strength}")
```

The signal generator analyzes these indicators:
- RSI (oversold/overbought levels)
- MACD (crossover and momentum)
- Stochastic (K/D crossovers)
- ADX (trend strength and direction)
- CCI (extreme levels)
- Momentum
- Awesome Oscillator
- Williams %R
- Bull Bear Power
- Ultimate Oscillator
- Moving Average alignment (10 MAs)

### Alert Manager

Evaluate trading alert conditions against live data:

```elixir
alias Lux.Prisms.TradingView.AlertManager

{:ok, alerts} = AlertManager.run(%{
  symbol: "BTCUSD",
  exchange: "BINANCE",
  screener: "crypto",
  interval: "1h",
  conditions: [
    # RSI oversold alert
    %{type: "threshold", indicator: "RSI", operator: "below", value: 30},
    # Price above level
    %{type: "threshold", indicator: "close", operator: "above", value: 50000.0},
    # MACD bullish crossover
    %{type: "crossover", indicator: "MACD.macd", indicator2: "MACD.signal", operator: "crosses_above"},
    # Overall recommendation is bullish
    %{type: "recommendation", target: "STRONG_BUY"}
  ]
})

if alerts.any_triggered do
  IO.puts("⚠️ Alerts triggered!")
  for alert <- alerts.alerts_triggered do
    IO.puts("  ✓ #{alert.condition} (current: #{inspect(alert.current_value)})")
  end
end
```

#### Condition Types

| Type | Description | Required Fields |
|------|-------------|----------------|
| `threshold` | Value crosses above/below a number | `indicator`, `operator`, `value` |
| `crossover` | One indicator crosses another | `indicator`, `indicator2`, `operator` |
| `recommendation` | Overall recommendation matches | `target` |

### Strategy Backtester

Evaluate trading strategies across multiple timeframes:

```elixir
alias Lux.Prisms.TradingView.StrategyBacktester

{:ok, backtest} = StrategyBacktester.run(%{
  symbol: "TSLA",
  exchange: "NASDAQ",
  screener: "america",
  strategy: %{
    name: "RSI Mean Reversion",
    entry_conditions: [
      %{indicator: "RSI", operator: "below", value: 30},
      %{indicator: "MACD.macd", operator: "above", value2: "MACD.signal"}
    ],
    exit_conditions: [
      %{indicator: "RSI", operator: "above", value: 70}
    ],
    stop_loss_pct: 5.0,
    take_profit_pct: 15.0
  },
  intervals: ["1h", "4h", "1d"]
})

IO.puts("Strategy: #{backtest.strategy_name}")
IO.puts("Signal: #{backtest.overall_signal}")
IO.puts("Current Price: $#{backtest.current_price}")
IO.puts("Stop Loss: $#{backtest.stop_loss_price}")
IO.puts("Take Profit: $#{backtest.take_profit_price}")
IO.puts("Risk/Reward: #{backtest.risk_reward_ratio}:1")

for {tf, result} <- backtest.timeframe_results do
  IO.puts("  #{tf}: entry=#{result.entry_met}, exit=#{result.exit_met}")
end
```

### Custom Script

Execute custom indicator logic against TradingView data:

```elixir
alias Lux.Prisms.TradingView.CustomScript

{:ok, result} = CustomScript.run(%{
  symbol: "TSLA",
  exchange: "NASDAQ",
  interval: "1d",
  scripts: [
    %{
      name: "Golden Cross",
      conditions: [
        %{left: "EMA50", op: ">", right: "SMA200"}
      ]
    },
    %{
      name: "RSI Divergence Setup",
      conditions: [
        %{left: "RSI", op: "<", right: 40},
        %{left: "MACD.macd", op: ">", right: "MACD.signal"},
        %{left: "close", op: ">", right: "EMA20"}
      ]
    },
    %{
      name: "Volume Breakout",
      conditions: [
        %{left: "close", op: ">", right: "SMA50"},
        %{left: "ADX", op: ">", right: 25}
      ]
    }
  ]
})

for script <- result.script_results do
  status = if script.result, do: "✅", else: "❌"
  IO.puts("#{status} #{script.name}")
end
```

## Supported Markets

### Screeners

| Screener | Region | Example Exchanges |
|----------|--------|-------------------|
| `america` | US/Canada | NASDAQ, NYSE, TSX |
| `crypto` | Cryptocurrency | BINANCE, COINBASE, BYBIT |
| `forex` | Forex | FX_IDC, OANDA, FOREX |
| `cfd` | CFDs | Various |
| `uk` | United Kingdom | LSE |
| `germany` | Germany | XETR |
| ... | Many more | See `TradingView.screeners()` |

### Intervals

| Code | Description |
|------|-------------|
| `1m` | 1 minute |
| `5m` | 5 minutes |
| `15m` | 15 minutes |
| `30m` | 30 minutes |
| `1h` | 1 hour |
| `2h` | 2 hours |
| `4h` | 4 hours |
| `1d` | 1 day (default) |
| `1W` | 1 week |
| `1M` | 1 month |

## Available Indicators

### Oscillators

RSI, Stochastic K/D, CCI(20), ADX, Awesome Oscillator, Momentum, MACD, Williams %R, Bull Bear Power, Ultimate Oscillator

### Moving Averages

EMA(10, 20, 30, 50, 100, 200), SMA(10, 20, 30, 50, 100, 200), Ichimoku Baseline, VWMA, Hull MA(9)

### Price Data

Open, High, Low, Close, Volume, Change (%), Change (absolute)

### Pivot Points

Classic pivot points: S3, S2, S1, Middle (Pivot), R1, R2, R3

## Integration with Lux Agents

Use TradingView analysis in your Lux agent workflows:

```elixir
defmodule MyApp.Agents.TradingAgent do
  use Lux.Agent,
    name: "Market Analyst",
    description: "Analyzes markets using TradingView data",
    lenses: [
      Lux.Lenses.TradingView.TechnicalAnalysis,
      Lux.Lenses.TradingView.IndicatorValues,
      Lux.Lenses.TradingView.ChartData,
      Lux.Lenses.TradingView.MultiTimeframeAnalysis
    ],
    prisms: [
      Lux.Prisms.TradingView.SignalGenerator,
      Lux.Prisms.TradingView.AlertManager,
      Lux.Prisms.TradingView.StrategyBacktester,
      Lux.Prisms.TradingView.CustomScript
    ]
end
```

## API Reference

### Integration Module

- `Lux.Integrations.TradingView` — Configuration, constants, utility functions
- `Lux.Integrations.TradingView.Client` — HTTP client for scanner API

### Lenses

- `Lux.Lenses.TradingView.TechnicalAnalysis` — TA summary (buy/sell/neutral)
- `Lux.Lenses.TradingView.IndicatorValues` — Raw indicator values
- `Lux.Lenses.TradingView.ChartData` — OHLCV data and pivot points
- `Lux.Lenses.TradingView.MultiTimeframeAnalysis` — Cross-timeframe analysis

### Prisms

- `Lux.Prisms.TradingView.SignalGenerator` — Trading signal generation
- `Lux.Prisms.TradingView.AlertManager` — Alert condition evaluation
- `Lux.Prisms.TradingView.StrategyBacktester` — Strategy backtesting
- `Lux.Prisms.TradingView.CustomScript` — Custom indicator scripts
