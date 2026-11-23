"""Pure-Python technical analysis indicator engine.

This module implements a collection of standard, well-documented technical
indicators (RSI, MACD, SMA, EMA, Bollinger Bands, Stochastic, ATR, OBV, VWAP)
computed directly over OHLCV candles.  It has **no third-party dependencies**
and performs **no network I/O**, which makes it fully deterministic and easy to
test offline.

The functions operate on plain Python lists of floats and return plain Python
lists / dicts so they can be consumed both by the :class:`TradingViewClient`
signal pipeline and by Lux prisms running inside the BEAM via ``erlport``.

All indicators follow their canonical TradingView / TA-Lib definitions:

* :func:`sma`  - Simple Moving Average
* :func:`ema`  - Exponential Moving Average
* :func:`rsi`  - Relative Strength Index (Wilder's smoothing)
* :func:`macd` - Moving Average Convergence Divergence
* :func:`bollinger_bands` - Bollinger Bands
* :func:`stochastic` - Stochastic Oscillator (%K / %D)
* :func:`atr`  - Average True Range (Wilder)
* :func:`obv`  - On-Balance Volume
* :func:`vwap` - Volume Weighted Average Price (session anchored)
"""

from __future__ import annotations

from typing import Dict, List, Optional, Sequence

__all__ = [
    "sma",
    "ema",
    "rsi",
    "macd",
    "bollinger_bands",
    "stochastic",
    "atr",
    "obv",
    "vwap",
    "highest",
    "lowest",
]


def _as_floats(values: Sequence[float]) -> List[float]:
    """Coerce an iterable of numbers into a list of floats."""
    return [float(v) for v in values]


def sma(values: Sequence[float], period: int) -> List[Optional[float]]:
    """Simple Moving Average.

    ``result[i]`` is the average of ``values[i-period+1 : i+1]``.  Positions
    before ``period-1`` are ``None`` because there is not enough history.
    """
    if period <= 0:
        raise ValueError("period must be a positive integer")
    data = _as_floats(values)
    out: List[Optional[float]] = [None] * len(data)
    if len(data) < period:
        return out
    window_sum = sum(data[:period])
    out[period - 1] = window_sum / period
    for i in range(period, len(data)):
        window_sum += data[i] - data[i - period]
        out[i] = window_sum / period
    return out


def ema(values: Sequence[float], period: int) -> List[Optional[float]]:
    """Exponential Moving Average.

    The first EMA value is seeded with the SMA of the first ``period`` points
    (matching TradingView's default ``ta.ema`` behaviour) and subsequent values
    use the multiplier ``2 / (period + 1)``.
    """
    if period <= 0:
        raise ValueError("period must be a positive integer")
    data = _as_floats(values)
    out: List[Optional[float]] = [None] * len(data)
    if len(data) < period:
        return out
    seed = sum(data[:period]) / period
    out[period - 1] = seed
    multiplier = 2.0 / (period + 1.0)
    prev = seed
    for i in range(period, len(data)):
        prev = (data[i] - prev) * multiplier + prev
        out[i] = prev
    return out


def rsi(values: Sequence[float], period: int = 14) -> List[Optional[float]]:
    """Relative Strength Index using Wilder's smoothing.

    Returns a list the same length as ``values`` where the first ``period``
    entries are ``None``.
    """
    if period <= 0:
        raise ValueError("period must be a positive integer")
    data = _as_floats(values)
    n = len(data)
    out: List[Optional[float]] = [None] * n
    if n <= period:
        return out

    gains = 0.0
    losses = 0.0
    for i in range(1, period + 1):
        change = data[i] - data[i - 1]
        if change >= 0:
            gains += change
        else:
            losses -= change
    avg_gain = gains / period
    avg_loss = losses / period

    def _rsi_value(avg_gain: float, avg_loss: float) -> float:
        if avg_loss == 0:
            return 100.0
        rs = avg_gain / avg_loss
        return 100.0 - (100.0 / (1.0 + rs))

    out[period] = _rsi_value(avg_gain, avg_loss)
    for i in range(period + 1, n):
        change = data[i] - data[i - 1]
        gain = change if change > 0 else 0.0
        loss = -change if change < 0 else 0.0
        avg_gain = (avg_gain * (period - 1) + gain) / period
        avg_loss = (avg_loss * (period - 1) + loss) / period
        out[i] = _rsi_value(avg_gain, avg_loss)
    return out


def macd(
    values: Sequence[float],
    fast_period: int = 12,
    slow_period: int = 26,
    signal_period: int = 9,
) -> Dict[str, List[Optional[float]]]:
    """Moving Average Convergence Divergence.

    Returns a dict with three aligned lists: ``macd`` (fast EMA - slow EMA),
    ``signal`` (EMA of the macd line) and ``histogram`` (macd - signal).
    """
    if fast_period <= 0 or slow_period <= 0 or signal_period <= 0:
        raise ValueError("MACD periods must be positive integers")
    if fast_period >= slow_period:
        raise ValueError("fast_period must be smaller than slow_period")

    data = _as_floats(values)
    fast = ema(data, fast_period)
    slow = ema(data, slow_period)

    macd_line: List[Optional[float]] = [
        (f - s) if (f is not None and s is not None) else None
        for f, s in zip(fast, slow)
    ]

    # The signal line is an EMA of the *defined* portion of the MACD line.
    first_defined = next(
        (i for i, v in enumerate(macd_line) if v is not None), len(macd_line)
    )
    defined_macd = [v for v in macd_line if v is not None]
    signal_defined = ema(defined_macd, signal_period)

    signal_line: List[Optional[float]] = [None] * len(data)
    for offset, value in enumerate(signal_defined):
        if value is not None:
            signal_line[first_defined + offset] = value

    histogram: List[Optional[float]] = [
        (m - s) if (m is not None and s is not None) else None
        for m, s in zip(macd_line, signal_line)
    ]

    return {"macd": macd_line, "signal": signal_line, "histogram": histogram}


def bollinger_bands(
    values: Sequence[float], period: int = 20, num_std: float = 2.0
) -> Dict[str, List[Optional[float]]]:
    """Bollinger Bands (SMA middle band +/- ``num_std`` population std dev)."""
    if period <= 0:
        raise ValueError("period must be a positive integer")
    data = _as_floats(values)
    middle = sma(data, period)
    upper: List[Optional[float]] = [None] * len(data)
    lower: List[Optional[float]] = [None] * len(data)

    for i in range(period - 1, len(data)):
        window = data[i - period + 1 : i + 1]
        mean = middle[i]
        assert mean is not None  # for type-checkers
        variance = sum((x - mean) ** 2 for x in window) / period
        std = variance ** 0.5
        upper[i] = mean + num_std * std
        lower[i] = mean - num_std * std

    return {"upper": upper, "middle": middle, "lower": lower}


def stochastic(
    highs: Sequence[float],
    lows: Sequence[float],
    closes: Sequence[float],
    k_period: int = 14,
    d_period: int = 3,
) -> Dict[str, List[Optional[float]]]:
    """Stochastic Oscillator.

    ``%K`` is the position of the close within the high/low range over
    ``k_period`` bars; ``%D`` is the SMA of ``%K`` over ``d_period`` bars.
    """
    if k_period <= 0 or d_period <= 0:
        raise ValueError("stochastic periods must be positive integers")
    highs_f = _as_floats(highs)
    lows_f = _as_floats(lows)
    closes_f = _as_floats(closes)
    if not (len(highs_f) == len(lows_f) == len(closes_f)):
        raise ValueError("highs, lows and closes must have equal length")

    n = len(closes_f)
    raw_k: List[Optional[float]] = [None] * n
    for i in range(k_period - 1, n):
        window_high = max(highs_f[i - k_period + 1 : i + 1])
        window_low = min(lows_f[i - k_period + 1 : i + 1])
        rng = window_high - window_low
        if rng == 0:
            raw_k[i] = 50.0
        else:
            raw_k[i] = (closes_f[i] - window_low) / rng * 100.0

    # %D = SMA of %K over d_period (only over defined %K values).
    d_line: List[Optional[float]] = [None] * n
    for i in range(n):
        if raw_k[i] is None:
            continue
        window = raw_k[i - d_period + 1 : i + 1]
        if len(window) == d_period and all(v is not None for v in window):
            d_line[i] = sum(v for v in window if v is not None) / d_period

    return {"k": raw_k, "d": d_line}


def true_range(
    highs: Sequence[float], lows: Sequence[float], closes: Sequence[float]
) -> List[Optional[float]]:
    """True Range for each bar (first bar is ``None``)."""
    highs_f = _as_floats(highs)
    lows_f = _as_floats(lows)
    closes_f = _as_floats(closes)
    n = len(closes_f)
    tr: List[Optional[float]] = [None] * n
    for i in range(1, n):
        tr[i] = max(
            highs_f[i] - lows_f[i],
            abs(highs_f[i] - closes_f[i - 1]),
            abs(lows_f[i] - closes_f[i - 1]),
        )
    return tr


def atr(
    highs: Sequence[float],
    lows: Sequence[float],
    closes: Sequence[float],
    period: int = 14,
) -> List[Optional[float]]:
    """Average True Range using Wilder's smoothing."""
    if period <= 0:
        raise ValueError("period must be a positive integer")
    tr = true_range(highs, lows, closes)
    n = len(tr)
    out: List[Optional[float]] = [None] * n
    if n <= period:
        return out

    # First ATR is the simple average of the first `period` true ranges.
    first_window = tr[1 : period + 1]
    if any(v is None for v in first_window):
        return out
    prev = sum(v for v in first_window if v is not None) / period
    out[period] = prev
    for i in range(period + 1, n):
        current_tr = tr[i]
        if current_tr is None:
            continue
        prev = (prev * (period - 1) + current_tr) / period
        out[i] = prev
    return out


def obv(closes: Sequence[float], volumes: Sequence[float]) -> List[float]:
    """On-Balance Volume."""
    closes_f = _as_floats(closes)
    volumes_f = _as_floats(volumes)
    if len(closes_f) != len(volumes_f):
        raise ValueError("closes and volumes must have equal length")
    out: List[float] = []
    running = 0.0
    for i in range(len(closes_f)):
        if i == 0:
            out.append(running)
            continue
        if closes_f[i] > closes_f[i - 1]:
            running += volumes_f[i]
        elif closes_f[i] < closes_f[i - 1]:
            running -= volumes_f[i]
        out.append(running)
    return out


def vwap(
    highs: Sequence[float],
    lows: Sequence[float],
    closes: Sequence[float],
    volumes: Sequence[float],
) -> List[float]:
    """Volume Weighted Average Price anchored to the start of the series.

    ``typical_price = (high + low + close) / 3`` and the result is the running
    volume-weighted average of the typical price.
    """
    highs_f = _as_floats(highs)
    lows_f = _as_floats(lows)
    closes_f = _as_floats(closes)
    volumes_f = _as_floats(volumes)
    if not (len(highs_f) == len(lows_f) == len(closes_f) == len(volumes_f)):
        raise ValueError("highs, lows, closes and volumes must have equal length")

    out: List[float] = []
    cum_pv = 0.0
    cum_vol = 0.0
    for h, l, c, v in zip(highs_f, lows_f, closes_f, volumes_f):
        typical = (h + l + c) / 3.0
        cum_pv += typical * v
        cum_vol += v
        out.append(cum_pv / cum_vol if cum_vol else typical)
    return out


def highest(values: Sequence[float], period: int) -> List[Optional[float]]:
    """Rolling maximum over ``period`` bars."""
    if period <= 0:
        raise ValueError("period must be a positive integer")
    data = _as_floats(values)
    out: List[Optional[float]] = [None] * len(data)
    for i in range(period - 1, len(data)):
        out[i] = max(data[i - period + 1 : i + 1])
    return out


def lowest(values: Sequence[float], period: int) -> List[Optional[float]]:
    """Rolling minimum over ``period`` bars."""
    if period <= 0:
        raise ValueError("period must be a positive integer")
    data = _as_floats(values)
    out: List[Optional[float]] = [None] * len(data)
    for i in range(period - 1, len(data)):
        out[i] = min(data[i - period + 1 : i + 1])
    return out