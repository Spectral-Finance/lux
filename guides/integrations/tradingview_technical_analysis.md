# TradingView Technical Analysis Integration

This integration provides robust tools to interface with TradingView data and perform pure Elixir technical analysis.

## Features
- **Chart data integration**: Fetch real-time OHLCV market data.
- **Technical indicator calculation**: Pure Elixir implementations of RSI, MACD, Bollinger Bands, SMA, EMA.
- **Custom script support**: Process array values offline.
- **Alert management**: Integration with TradingView webhooks/alerts.
- **Strategy backtesting**: Signal analyzer for analyzing multiple indicators and backtesting historically.
- **Screener**: Connect to TradingView scanner API.

## Usage

```elixir
alias Lux.Lenses.TradingView.TechnicalAnalysis

prices = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
sma_values = TechnicalAnalysis.sma(prices, 5)
```
