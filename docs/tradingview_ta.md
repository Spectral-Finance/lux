# TradingView Technical Analysis Integration

Production-grade TradingView technical-analysis integration for Lux, implementing
[issue #86](https://github.com/Spectral-Finance/lux/issues/86).

It provides a clean Python client for TradingView's public **scanner/screener**
endpoint plus a self-contained, offline-capable **indicator engine**, signal
generation, multi-timeframe analysis, an alert system, and a minimal strategy
backtester.

## Layout

```
lux/priv/python/lux/ta/
├── __init__.py       # public exports
├── indicators.py     # pure-Python TA indicator engine (no deps)
├── client.py         # TradingViewClient: retries, caching, typed responses
└── features.py       # multi-timeframe, alerts, backtesting
tradingview_ta.py     # top-level convenience module + offline demo
lux/test/python/      # offline pytest suite (46 tests)
```

## Quick start

```python
from lux.ta import TradingViewClient

client = TradingViewClient()                 # uses TradingView scanner
analysis = client.analyze("NASDAQ:AAPL", timeframe="1d")

print(analysis.symbol, analysis.bias)        # AAPL bullish
print(analysis.signals)                       # ['MACD_BULLISH_BUY', ...]
print(analysis.indicators["rsi_14"])          # 58.3
```

### Offline / custom data

Inject any OHLCV provider (e.g. a CSV loader, a broker feed, or test fixtures)
without touching the network:

```python
from lux.ta import TradingViewClient, Candle

def my_provider(symbol, timeframe, limit):
    return [Candle(time=i, open=1, high=2, low=0.5, close=1.5, volume=100)
            for i in range(limit)]

client = TradingViewClient(ohlcv_provider=my_provider)
print(client.analyze("DEMO:SYM").bias)
```

## Indicators (`lux.ta.indicators`)

All functions accept a list of floats and return a list aligned to the input
(`None` where undefined due to warm-up):

| Indicator | Function | Notes |
|-----------|----------|-------|
| SMA | `sma(values, period)` | simple moving average |
| EMA | `ema(values, period)` | exponential moving average |
| RSI | `rsi(values, period=14)` | Wilder's RSI |
| MACD | `macd(values, fast, slow, signal)` | returns (macd, signal, histogram) |
| Bollinger Bands | `bollinger_bands(values, period, std)` | returns (upper, middle, lower) |
| Stochastic | `stochastic(highs, lows, closes, k_period, d_period)` | %K / %D |
| ATR | `atr(highs, lows, closes, period)` | Average True Range |
| OBV | `obv(closes, volumes)` | On-Balance Volume |
| VWAP | `vwap(highs, lows, closes, volumes)` | session VWAP |

## Signals

`client.generate_signals(candles)` returns a list of typed signal strings such
as `RSI_OVERBOUGHT_SELL`, `MACD_BULLISH_BUY`, `PRICE_ABOVE_SMA50_BUY`,
`ABOVE_BOLLINGER_SELL`. `client.analyze(...)` aggregates these into a
`bullish` / `bearish` / `neutral` bias.

## Multi-timeframe analysis

```python
from lux.ta import multi_timeframe_analysis

result = multi_timeframe_analysis(client, "NASDAQ:AAPL",
                                  timeframes=("1d", "1h", "15m"))
print(result["consensus"])   # majority-vote bias across timeframes
```

## Alerts

```python
from lux.ta import AlertManager, AlertDialog

mgr = AlertManager([
    AlertDialog(name="rsi_hot", kind="rsi_above", threshold=70),
    AlertDialog(name="breakout", kind="above", threshold=200.0),
])
for alert in mgr.evaluate("NASDAQ:AAPL", candles):
    print(alert.rule, alert.message)
```

Supported kinds: `above`, `below`, `rsi_above`, `rsi_below`.

## Strategy backtesting

```python
from lux.ta import backtest

result = backtest("NASDAQ:AAPL", candles,
                  signal_fn=lambda w: 1 if len(w) >= 20 else 0,
                  initial_capital=10_000.0)
print(result.total_return_pct, result.win_rate_pct, result.trades)
```

## TradingView client features

* **Retries** with exponential backoff on transient 5xx / connection errors.
* **In-memory caching** with a configurable TTL keyed by `(symbol, timeframe)`.
* **Typed responses** via `Candle`, `TechnicalRating`, and `AnalysisResult`
  dataclasses.
* **Injectable transport** (`http_post_json`) and OHLCV provider for fully
  offline testing.

## Scope notes

* **Custom script (Pine) execution** and **real-time WebSocket streaming** are
  intentionally out of scope: Pine requires TradingView's proprietary runtime,
  and streaming requires their WebSocket protocol. The client architecture
  leaves room to add a streaming transport later without changing callers.

## Testing

The suite runs fully offline (mocked HTTP + synthetic OHLCV fixtures):

```bash
pytest -q
```

## License

MIT — part of the Lux repository.