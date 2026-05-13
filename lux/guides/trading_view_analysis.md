# TradingView Technical Analysis

`Lux.Integrations.TradingView.Analysis` provides deterministic, data-source agnostic market analysis helpers for TradingView-style OHLCV data. A lens, prism, or external adapter can fetch chart candles from a TradingView-compatible feed, REST endpoint, or WebSocket stream, then pass normalized bars into this module for indicators, alerts, signals, multi-timeframe summaries, and strategy checks.

## Normalized Bars

Bars can use either long or short OHLCV keys:

```elixir
bars = [
  %{time: "2026-05-13T00:00:00Z", open: 100, high: 104, low: 99, close: 103, volume: 1200},
  %{timestamp: "2026-05-13T00:01:00Z", o: 103, h: 106, l: 102, c: 105, v: 1800}
]

Lux.Integrations.TradingView.Analysis.normalize_bars(bars)
```

Normalized bars are sorted by time and converted to numeric OHLCV fields. That makes downstream calculations stable regardless of whether a caller uses REST payload names or compact chart-feed names.

## Indicators

The module includes common technical indicators used by TradingView workflows:

```elixir
alias Lux.Integrations.TradingView.Analysis

Analysis.sma(bars, 20)
Analysis.ema(bars, 20)
Analysis.rsi(bars, 14)
Analysis.macd(bars, %{fast: 12, slow: 26, signal: 9})
Analysis.bollinger_bands(bars, %{period: 20, multiplier: 2})
```

Each indicator point includes the source time, close, rounded value, and params, so agents can persist or explain the generated values.

## Alerts And Signals

Alert rules can target the latest candle or supplied indicator values:

```elixir
alerts =
  Analysis.evaluate_alerts(
    bars,
    [
      %{source: :close, operator: :gt, threshold: 100},
      %{source: :rsi, operator: :gte, threshold: 70}
    ],
    %{rsi: 72.3}
  )
```

`generate_signals/2` combines short and long SMA values with RSI into a simple directional signal:

```elixir
Analysis.generate_signals(bars, %{
  symbol: "ETHUSDT",
  short_sma: 5,
  long_sma: 20,
  rsi_period: 14
})
```

`multi_timeframe_summary/2` runs that same signal engine across multiple timeframe datasets and returns a bullish, bearish, or neutral consensus.

## Backtesting

`backtest_crossover/2` runs a simple SMA crossover strategy with optional fee basis points:

```elixir
Analysis.backtest_crossover(bars, %{short: 9, long: 21, fee_bps: 5})
```

The result includes the strategy parameters, trade count, total return, and individual entry/exit records. It is intentionally small and deterministic, making it useful as a foundation for richer trading agents without requiring network calls in tests.
