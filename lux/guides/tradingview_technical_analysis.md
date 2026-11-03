# TradingView Technical Analysis Integration

This guide provides comprehensive documentation and implementation examples for the TradingView Technical Analysis system in Lux.

The module provides end-to-end capabilities spanning historical chart data ingestion, technical indicator calculation, custom Pine Script execution, multi-indicator confluence scoring, real-time tick streaming, threshold alert management, cross-timeframe consensus, and strategy backtesting.

---

## Architecture Overview

The TradingView integration adheres to Lux's composable primitives:

```
[ Market Data Provider / Binance UDF / Synthetic ]
                         │
                         ▼
             [ ChartDataLens / StreamLens ]
                         │
                         ▼
                 [ ChartDataPrism ]
                         │
                         ▼
           [ IndicatorCalculatorPrism ]
            ├── SMA / EMA
            ├── RSI (Wilder Smoothing)
            ├── MACD (Line / Signal / Hist)
            ├── Bollinger Bands (%B / BW)
            ├── ATR
            ├── Stochastic (%K / %D)
            └── SuperTrend (Direction / ATR Band)
                         │
        ┌────────────────┼────────────────┐
        ▼                ▼                ▼
[ SignalGenerator ] [ PineScriptPrism ] [ Alerts / Backtester ]
(Confluence -100..100) (Custom Rule Engine) (Trigger / Simulation)
        │                │                │
        └────────────────┼────────────────┘
                         ▼
        [ TechnicalAnalysisBeam (Orchestrator) ]
```

### Core Components

1. **`Lux.TradingView.Indicators`**: Low-level math engine computing SMA, EMA, RSI with Wilder smoothing, MACD, Bollinger Bands, ATR, Stochastic, and SuperTrend.
2. **`Lux.TradingView.PineScript`**: Safe AST parser and execution sandbox for TradingView Pine Script expressions and boolean conditions.
3. **`Lux.TradingView.Signals`**: Confluence engine evaluating momentum, trend, and volatility to emit directional recommendations (`:strong_buy`, `:buy`, `:neutral`, `:sell`, `:strong_sell`).
4. **`Lux.TradingView.Alerts`**: Alert lifecycle manager with threshold breaches, band breakouts, and configurable cooldown windows.
5. **`Lux.TradingView.Backtester`**: Historical backtesting simulator computing Win Rate %, Total Return %, Profit Factor, and Max Drawdown %.
6. **`Lux.TradingView.MultiTimeframe`**: Cross-resolution consensus aggregator evaluating 15m, 1h, 4h, and 1D signals.
7. **`Lux.Lenses.TradingView.ChartDataLens` & `StreamLens`**: Data feeds for historical OHLCV klines and real-time Pub/Sub bar streaming.
8. **Prisms & Beam**:
   - `Lux.Prisms.TradingView.ChartDataPrism`
   - `Lux.Prisms.TradingView.IndicatorCalculatorPrism`
   - `Lux.Prisms.TradingView.PineScriptPrism`
   - `Lux.Prisms.TradingView.SignalGeneratorPrism`
   - `Lux.Prisms.TradingView.MultiTimeframePrism`
   - `Lux.Prisms.TradingView.StrategyBacktestPrism`
   - `Lux.Prisms.TradingView.TradingViewAlertPrism`
   - `Lux.Beams.TradingView.TechnicalAnalysisBeam`

---

## 1. Chart Data Retrieval

### Historical OHLCV Candles via `ChartDataLens`

```elixir
alias Lux.Lenses.TradingView.ChartDataLens

# Fetch historical 1-hour candles for BTCUSDT
{:ok, response} = ChartDataLens.focus(%{
  symbol: "BTCUSDT",
  resolution: "1h",
  limit: 100
})

candles = response.candles
# Each candle: %{timestamp: integer, open: float, high: float, low: float, close: float, volume: float}
```

### Deterministic Synthetic Data (for Testing & Offline Use)

```elixir
# Generate 50 continuous synthetic candles for testing
synthetic_candles = ChartDataLens.generate_synthetic_candles("ETHUSDT", "15m", 50)
```

---

## 2. Technical Indicators

The `Lux.TradingView.Indicators` module supports single-value summaries and full time-series calculations.

### Moving Averages (SMA & EMA)

```elixir
alias Lux.TradingView.Indicators

closes = [44.34, 44.09, 44.15, 43.61, 44.33, 44.83, 45.10, 45.42, 45.84, 46.08]

# Simple Moving Average
{:ok, sma_values} = Indicators.sma(closes, 5)

# Exponential Moving Average
{:ok, ema_values} = Indicators.ema(closes, 5)
```

### Relative Strength Index (RSI) with Wilder Smoothing

Wilder's smoothed moving average prevents jumpiness in momentum analysis:

```elixir
{:ok, rsi_series} = Indicators.rsi(closes, 14)
current_rsi = List.last(rsi_series)
```

### Moving Average Convergence Divergence (MACD)

```elixir
{:ok, macd} = Indicators.macd(closes, 12, 26, 9)

macd.macd       # Fast EMA minus Slow EMA
macd.signal     # Signal EMA of the MACD line
macd.histogram  # MACD line minus Signal line
```

### Bollinger Bands

```elixir
{:ok, bb} = Indicators.bollinger_bands(closes, 20, 2.0)

bb.middle     # 20-period SMA
bb.upper      # Middle + 2 standard deviations
bb.lower      # Middle - 2 standard deviations
bb.percent_b  # (Price - Lower) / (Upper - Lower)
bb.bandwidth  # (Upper - Lower) / Middle
```

### Average True Range (ATR) & SuperTrend

```elixir
{:ok, atr_series} = Indicators.atr(candles, 14)
{:ok, supertrend} = Indicators.supertrend(candles, 10, 3.0)

supertrend.supertrend # Band price
supertrend.direction  # 1 (Bullish) or -1 (Bearish)
```

### Comprehensive Technical Summary

```elixir
{:ok, summary} = Indicators.calculate_all(candles)
# Contains current_price, rsi, macd, bollinger, sma_20, ema_20, atr, stochastic
```

---

## 3. Pine Script Execution

Run custom TradingView Pine Script expressions and boolean triggers inside Lux agents:

```elixir
alias Lux.TradingView.PineScript

script = """
fast = ta.sma(close, 5)
slow = ta.sma(close, 20)
bullish = ta.crossover(fast, slow)
prev_close = close[1]
"""

{:ok, env} = PineScript.eval(script, candles)

env["fast"]        # Latest fast SMA float
env["slow"]        # Latest slow SMA float
env["bullish"]     # Boolean crossover condition
env["prev_close"]  # Lookback series value
```

### Single Rule Evaluation with Context

```elixir
context = %{
  "close" => 65_200.0,
  "ema" => 64_800.0,
  "rsi" => 48.0
}

{:ok, result} = PineScript.execute("close > ema and rsi < 70", context)
# => %{triggered?: true, result: true, variables: context}
```

---

## 4. Multi-Indicator Confluence Scoring

The confluence engine calculates a score bounded between -100 (Maximum Bearish) and +100 (Maximum Bullish):

```elixir
alias Lux.TradingView.Signals

signal = Signals.generate_signal(candles)

signal.score          # e.g. 75
signal.recommendation # :strong_buy | :buy | :neutral | :sell | :strong_sell
signal.rsi_signal     # :bullish | :bearish | :neutral
signal.macd_signal    # :bullish | :bearish | :neutral
signal.bb_signal      # :bullish | :bearish | :neutral
signal.stoch_signal   # :bullish | :bearish | :neutral
```

---

## 5. Real-Time Bar & Tick Streaming

Using `Lux.Lenses.TradingView.StreamLens`, agents can subscribe to real-time candlestick bars:

```elixir
alias Lux.Lenses.TradingView.StreamLens

# Start or connect to stream process
{:ok, stream} = StreamLens.start_link()

# Subscribe current process to symbol events
:ok = StreamLens.subscribe(stream, "BTCUSDT")

# Handle streamed events in GenServer / LiveView
def handle_info({:tradingview_bar, "BTCUSDT", bar}, state) do
  # Trigger indicators, alerts, or orders on new bar
  {:noreply, state}
end
```

---

## 6. Alert System Integration

Manage alert rules with automatic cooldown suppression:

```elixir
alias Lux.TradingView.Alerts

rules = [
  %{id: "rsi_overbought", condition: :rsi_overbought, threshold: 70.0, cooldown_sec: 300},
  %{id: "price_breakout", condition: :price_above, threshold: 70_000.0, cooldown_sec: 600},
  %{id: "bb_squeeze_break", condition: :bb_breakout_upper, cooldown_sec: 120}
]

snapshot = %{
  symbol: "BTCUSDT",
  current_price: 70_500.0,
  rsi: 74.5,
  bollinger_bands: %{upper: 69_800.0, lower: 66_000.0}
}

{:ok, alert_report} = Alerts.evaluate_alerts(rules, snapshot)

# alert_report.triggered_alerts -> List of triggered events with reason and timestamp
```

---

## 7. Strategy Backtesting

Simulate trading strategies on historical data with win rate and drawdown verification:

```elixir
alias Lux.TradingView.Backtester

# Backtest Moving Average Crossover
result = Backtester.run_backtest(candles, :ma_crossover, %{
  fast_ma: 9,
  slow_ma: 21
})

result.total_trades      # Total roundtrip executions
result.winning_trades    # Profitable trades
result.losing_trades     # Loss trades
result.win_rate_pct      # Win rate percentage (e.g. 62.5%)
result.total_return_pct  # Cumulative strategy return %
result.max_drawdown_pct  # Maximum peak-to-trough drawdown %
result.profit_factor     # Gross profit / Gross loss
result.trades            # Itemized trade audit log
```

Supported backtesting strategies:
- `:ma_crossover` (fast and slow moving average crossovers)
- `:rsi_reversal` (mean-reversion on oversold/overbought thresholds)
- `:bollinger_breakout` (volatility breakout outside upper/lower bands)

---

## 8. Multi-Timeframe Consensus

Confirm alignment across multiple timeframes before initiating trades:

```elixir
alias Lux.TradingView.MultiTimeframe

signals = [
  %{timeframe: "15m", recommendation: :buy},
  %{timeframe: "1h", recommendation: :strong_buy},
  %{timeframe: "4h", score: 40},
  %{timeframe: "1D", recommendation: :buy}
]

consensus = MultiTimeframe.calculate_consensus(signals)

consensus.overall_bias   # :bullish
consensus.consensus_pct  # 100.0
consensus.bullish_count  # 4
consensus.bearish_count  # 0
```

---

## 9. Full Orchestration with `TechnicalAnalysisBeam`

Run the end-to-end pipeline in a single Lux Beam execution:

```elixir
alias Lux.Beams.TradingView.TechnicalAnalysisBeam

{:ok, result, log} = TechnicalAnalysisBeam.run(%{
  symbol: "ETHUSDT",
  prices: closes
})

# Access step results and telemetry
log.status # :completed
log.steps  # [:indicators, :signals, :alerts]
```
