# TradingView Technical Analysis

Lux includes TradingView-style technical-analysis helpers for OHLCV candles.

## Analyze Candles

```elixir
candles = [
  %{time: "2026-06-15T10:00:00Z", open: 100, high: 103, low: 99, close: 102, volume: 10_000},
  %{time: "2026-06-15T11:00:00Z", open: 102, high: 105, low: 101, close: 104, volume: 12_000}
]

{:ok, %{analysis: analysis}} =
  Lux.Prisms.TradingView.AnalyzeSeries.run(%{
    candles: candles,
    sma_period: 2,
    ema_period: 2,
    rsi_period: 2
  })

analysis.indicators.sma
analysis.latest_signal
analysis.alerts
```

## Backtest SMA Cross

```elixir
{:ok, %{backtest: backtest}} =
  Lux.Prisms.TradingView.BacktestSmaCross.run(%{
    candles: candles,
    fast_period: 2,
    slow_period: 5
  })

backtest.signal_counts
```

The implementation returns chart-ready `%{time, value}` series so applications can render them in TradingView widgets or another charting library.
