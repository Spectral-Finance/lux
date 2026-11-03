# TradingView Technical Analysis Integration Guide

## Overview

The `Lux.TradingView` suite provides a complete technical analysis, signal generation, multi-timeframe consensus, strategy backtesting, and automated chart alert system for crypto and traditional financial instruments.

---

## Architectural Components

1. **`Lux.TradingView.Indicators`**
   - **RSI (Relative Strength Index):** 14-period Wilder smoothing algorithm.
   - **MACD (Moving Average Convergence Divergence):** 12 EMA, 26 EMA, 9 Signal Line, and MACD Histogram.
   - **Bollinger Bands:** 20-period SMA with $\pm 2.0$ standard deviation upper/lower bands and bandwidth percentage.
   - **Moving Averages:** Simple Moving Average (SMA) and Exponential Moving Average (EMA).

2. **`Lux.TradingView.Signals`**
   - Synthesizes RSI, MACD, and Bollinger Bands into a unified market bias score ranging from $-100$ (Strong Sell) to $+100$ (Strong Buy).
   - Generates action recommendations: `:strong_buy`, `:buy`, `:neutral`, `:sell`, `:strong_sell`.

3. **`Lux.TradingView.Backtester`**
   - Simulates technical strategies across historical candlestick arrays.
   - Computes Win Rate %, Total Return %, Profit Factor, and Maximum Drawdown %.

4. **`Lux.TradingView.MultiTimeframe`**
   - Computes trend consensus across disparate chart intervals (15m, 1h, 4h, 1D).
   - Evaluates multi-timeframe confirmation before trade execution.

---

## Prisms

- `Lux.Prisms.TradingView.IndicatorCalculatorPrism`: Calculates RSI, MACD, Bollinger Bands, and EMAs.
- `Lux.Prisms.TradingView.SignalGeneratorPrism`: Evaluates indicators to output composite score and recommendation.
- `Lux.Prisms.TradingView.MultiTimeframePrism`: Computes timeframe alignment and consensus strength.
- `Lux.Prisms.TradingView.StrategyBacktestPrism`: Runs historical strategy simulation and performance metrics.
- `Lux.Prisms.TradingView.TradingViewAlertPrism`: Evaluates trigger conditions for overbought, oversold, and band breakouts.

---

## Beam Workflow

`Lux.Beams.TradingView.TechnicalAnalysisBeam` coordinates:
1. Calculates core indicators with `IndicatorCalculatorPrism`.
2. Computes overall bias and sentiment with `SignalGeneratorPrism`.
3. Checks extreme breakout alerts with `TradingViewAlertPrism`.

---

## Quickstart

```elixir
prices = [45.0, 46.2, 47.1, 48.0, 49.5, 51.0, 52.3, 53.0, 54.2, 55.0]

# 1. Compute indicators
{:ok, indicators} = Lux.Prisms.TradingView.IndicatorCalculatorPrism.run(%{
  prices: prices
})

# 2. Generate signal recommendation
{:ok, signal} = Lux.Prisms.TradingView.SignalGeneratorPrism.run(%{
  current_price: 55.0,
  rsi: 72.5,
  macd: indicators.macd,
  bollinger_bands: indicators.bollinger_bands
})

# 3. Coordinate pipeline via TechnicalAnalysisBeam
{:ok, result} = Lux.Beams.TradingView.TechnicalAnalysisBeam.run(%{
  symbol: "BTCUSDT",
  prices: prices
})
```
