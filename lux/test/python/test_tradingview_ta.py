"""Offline test-suite for the TradingView technical-analysis integration.

These tests exercise:

* every indicator in :mod:`lux.ta.indicators` against hand-computed values,
* :class:`lux.ta.client.TradingViewClient` candle coercion, signal generation,
  retry/backoff behaviour, caching, and screener parsing — all with a fake
  HTTP transport (no network, no credentials required).

Run from the repository root::

    pytest -q
"""

import math
import os
import sys

import pytest

# Make ``lux`` importable regardless of the working directory.
_HERE = os.path.dirname(os.path.abspath(__file__))
_PRIV_PYTHON = os.path.abspath(os.path.join(_HERE, "..", "..", "priv", "python"))
if _PRIV_PYTHON not in sys.path:
    sys.path.insert(0, _PRIV_PYTHON)

from lux.ta import indicators  # noqa: E402
from lux.ta.client import (  # noqa: E402
    Candle,
    TechnicalRating,
    TradingViewClient,
    TradingViewError,
)


# --------------------------------------------------------------------------- #
# Fixtures / helpers
# --------------------------------------------------------------------------- #
@pytest.fixture
def linear_series():
    """A simple monotonically increasing series: 1..20."""
    return [float(x) for x in range(1, 21)]


@pytest.fixture
def ohlcv_candles():
    """Deterministic OHLCV candles with a gentle uptrend + oscillation."""
    candles = []
    price = 100.0
    for i in range(120):
        wave = math.sin(i / 4.0)
        open_ = price
        close = price + 0.5 + wave
        high = max(open_, close) + 1.0
        low = min(open_, close) - 1.0
        volume = 1000.0 + (i % 5) * 100.0
        candles.append(
            Candle(
                time=1_700_000_000 + i * 3600,
                open=open_,
                high=high,
                low=low,
                close=close,
                volume=volume,
            )
        )
        price = close
    return candles


def _provider(candles):
    def _p(symbol, timeframe, limit):
        return candles[:limit]

    return _p


# --------------------------------------------------------------------------- #
# Indicator tests
# --------------------------------------------------------------------------- #
def test_sma_basic():
    values = [1, 2, 3, 4, 5]
    result = indicators.sma(values, 3)
    assert result[:2] == [None, None]
    assert result[2] == pytest.approx(2.0)
    assert result[3] == pytest.approx(3.0)
    assert result[4] == pytest.approx(4.0)


def test_sma_insufficient_data():
    assert indicators.sma([1, 2], 5) == [None, None]


def test_sma_invalid_period():
    with pytest.raises(ValueError):
        indicators.sma([1, 2, 3], 0)


def test_ema_seeded_with_sma():
    values = [1.0, 2.0, 3.0, 4.0, 5.0]
    result = indicators.ema(values, 3)
    assert result[0] is None
    assert result[1] is None
    # Seed == SMA of first 3 == 2.0
    assert result[2] == pytest.approx(2.0)
    # Next: (4 - 2) * (2/4) + 2 = 3.0
    assert result[3] == pytest.approx(3.0)


def test_ema_multiplies_correctly():
    values = [10.0, 11.0, 12.0, 13.0, 14.0]
    result = indicators.ema(values, 2)
    # seed = (10+11)/2 = 10.5
    assert result[1] == pytest.approx(10.5)
    # (12 - 10.5) * (2/3) + 10.5 = 11.5
    assert result[2] == pytest.approx(11.5)


def test_rsi_all_gains_is_100():
    # Strictly increasing -> no losses -> RSI == 100.
    values = [float(x) for x in range(1, 30)]
    result = indicators.rsi(values, 14)
    assert result[13] is None
    assert result[14] == pytest.approx(100.0)
    assert result[-1] == pytest.approx(100.0)


def test_rsi_all_losses_is_0():
    values = [float(x) for x in range(30, 1, -1)]
    result = indicators.rsi(values, 14)
    assert result[14] == pytest.approx(0.0)


def test_rsi_length_and_none_prefix():
    values = [1.0, 2.0, 1.5, 3.0, 2.0, 4.0, 3.5, 5.0]
    result = indicators.rsi(values, 4)
    assert len(result) == len(values)
    assert all(v is None for v in result[:4])
    assert result[4] is not None


def test_macd_structure_and_alignment():
    values = [float(x) for x in range(1, 60)]
    macd = indicators.macd(values, fast_period=12, slow_period=26, signal_period=9)
    assert set(macd.keys()) == {"macd", "signal", "histogram"}
    n = len(values)
    assert len(macd["macd"]) == n
    assert len(macd["signal"]) == n
    assert len(macd["histogram"]) == n
    # MACD line is None until slow EMA is defined (index 25).
    assert macd["macd"][24] is None
    assert macd["macd"][25] is not None
    # Histogram == macd - signal where both defined.
    for m, s, h in zip(macd["macd"], macd["signal"], macd["histogram"]):
        if m is not None and s is not None:
            assert h == pytest.approx(m - s)


def test_macd_invalid_periods():
    with pytest.raises(ValueError):
        indicators.macd([1, 2, 3], fast_period=26, slow_period=12)


def test_bollinger_bands():
    values = [float(x) for x in range(1, 31)]
    bb = indicators.bollinger_bands(values, period=20, num_std=2.0)
    assert bb["upper"][18] is None
    mid = bb["middle"][19]
    up = bb["upper"][19]
    low = bb["lower"][19]
    assert mid == pytest.approx(sum(values[:20]) / 20)
    assert up > mid > low
    # Symmetric around the mean.
    assert (up - mid) == pytest.approx(mid - low)


def test_stochastic_bounds():
    highs = [10.0, 11.0, 12.0, 11.0, 13.0, 14.0, 13.0, 15.0]
    lows = [8.0, 9.0, 10.0, 9.0, 11.0, 12.0, 11.0, 13.0]
    closes = [9.0, 10.0, 11.0, 10.0, 12.0, 13.0, 12.0, 14.0]
    st = indicators.stochastic(highs, lows, closes, k_period=3, d_period=2)
    for v in st["k"]:
        if v is not None:
            assert 0.0 <= v <= 100.0
    for v in st["d"]:
        if v is not None:
            assert 0.0 <= v <= 100.0


def test_atr_positive():
    highs = [10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0]
    lows = [8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0]
    closes = [9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0]
    result = indicators.atr(highs, lows, closes, period=3)
    defined = [v for v in result if v is not None]
    assert defined, "ATR should produce defined values"
    assert all(v > 0 for v in defined)


def test_obv_direction():
    closes = [10.0, 11.0, 10.5, 12.0]
    volumes = [100.0, 200.0, 300.0, 400.0]
    result = indicators.obv(closes, volumes)
    assert result[0] == 0.0
    assert result[1] == 200.0  # up
    assert result[2] == 200.0 - 300.0  # down
    assert result[3] == (200.0 - 300.0) + 400.0  # up


def test_vwap_typical_price():
    highs = [12.0]
    lows = [10.0]
    closes = [11.0]
    volumes = [100.0]
    result = indicators.vwap(highs, lows, closes, volumes)
    assert result[0] == pytest.approx(11.0)  # (12+10+11)/3


def test_highest_lowest():
    values = [1.0, 5.0, 3.0, 2.0, 8.0]
    assert indicators.highest(values, 2)[-1] == 8.0
    assert indicators.lowest(values, 2)[-1] == 2.0


# --------------------------------------------------------------------------- #
# Client: candle coercion
# --------------------------------------------------------------------------- #
def test_coerce_candles_from_dicts():
    raw = [
        {"time": 1, "open": 1, "high": 2, "low": 0.5, "close": 1.5, "volume": 10},
        {"time": 2, "open": 1.5, "high": 3, "low": 1, "close": 2.5, "volume": 20},
    ]
    candles = TradingViewClient._coerce_candles(raw)
    assert len(candles) == 2
    assert candles[0].close == 1.5
    assert candles[1].volume == 20.0


def test_coerce_candles_from_tuples():
    raw = [(1, 1.0, 2.0, 0.5, 1.5, 10.0)]
    candles = TradingViewClient._coerce_candles(raw)
    assert candles[0].high == 2.0


def test_get_ohlcv_requires_provider():
    client = TradingViewClient()
    with pytest.raises(TradingViewError):
        client.get_ohlcv("BTCUSDT")


def test_get_ohlcv_empty_raises():
    client = TradingViewClient(ohlcv_provider=_provider([]))
    with pytest.raises(TradingViewError):
        client.get_ohlcv("BTCUSDT")


# --------------------------------------------------------------------------- #
# Client: indicators + signals
# --------------------------------------------------------------------------- #
def test_compute_indicators_keys(ohlcv_candles):
    client = TradingViewClient(ohlcv_provider=_provider(ohlcv_candles))
    ind = client.compute_indicators(ohlcv_candles)
    for key in (
        "sma_20",
        "sma_50",
        "ema_12",
        "ema_26",
        "rsi_14",
        "macd",
        "macd_signal",
        "bb_upper",
        "bb_lower",
        "stoch_k",
        "atr_14",
        "obv",
        "vwap",
        "close",
    ):
        assert key in ind
    assert ind["close"] == pytest.approx(ohlcv_candles[-1].close)


def test_generate_signals_oversold():
    client = TradingViewClient()
    signals = client.generate_signals(
        {"rsi_14": 20.0, "close": 100.0, "sma_50": 110.0}
    )
    assert "RSI_OVERSOLD_BUY" in signals
    assert "PRICE_BELOW_SMA50_SELL" in signals


def test_generate_signals_overbought():
    client = TradingViewClient()
    signals = client.generate_signals(
        {"rsi_14": 80.0, "close": 120.0, "sma_50": 100.0}
    )
    assert "RSI_OVERBOUGHT_SELL" in signals
    assert "PRICE_ABOVE_SMA50_BUY" in signals


def test_generate_signals_macd():
    client = TradingViewClient()
    bull = client.generate_signals({"macd": 2.0, "macd_signal": 1.0})
    bear = client.generate_signals({"macd": 1.0, "macd_signal": 2.0})
    assert "MACD_BULLISH_BUY" in bull
    assert "MACD_BEARISH_SELL" in bear


def test_analyze_end_to_end(ohlcv_candles):
    client = TradingViewClient(ohlcv_provider=_provider(ohlcv_candles))
    result = client.analyze("TEST:SYM", timeframe="1d", limit=120)
    assert result.candles == 120
    assert result.symbol == "TEST:SYM"
    assert isinstance(result.signals, list)
    assert result.bias in {"bullish", "bearish", "neutral"}


# --------------------------------------------------------------------------- #
# Client: screener parsing + retries + caching
# --------------------------------------------------------------------------- #
def _fake_scanner_payload():
    return {
        "totalCount": 26,
        "data": [
            {
                "s": "NASDAQ:AAPL",
                "d": [
                    -0.5,  # Recommend.All -> BUY
                    {
                        "COMPUTE": {"Bullish": 12, "Bearish": 4},
                    },
                ],
            }
        ],
    }


def test_get_technical_rating_parses():
    calls = []

    def transport(method, url, payload):
        calls.append((method, url, payload))
        return 200, _fake_scanner_payload()

    client = TradingViewClient(transport=transport)
    rating = client.get_technical_rating("NASDAQ:AAPL", timeframe="1d")
    assert isinstance(rating, TechnicalRating)
    assert rating.recommendation == "BUY"
    assert rating.buy_count == 12
    assert rating.sell_count == 4
    assert rating.neutral_count == 26 - 12 - 4
    assert rating.score > 0
    assert len(calls) == 1


def test_rating_recommendation_mapping():
    for value, expected in [
        (1.0, "STRONG_SELL"),
        (0.5, "SELL"),
        (0.0, "NEUTRAL"),
        (-0.5, "BUY"),
        (-1.0, "STRONG_BUY"),
    ]:
        payload = {
            "totalCount": 1,
            "data": [{"s": "X", "d": [value, {"COMPUTE": {}}]}],
        }
        client = TradingViewClient(transport=lambda m, u, p, pl=payload: (200, pl))
        rating = client.get_technical_rating("X")
        assert rating.recommendation == expected


def test_retry_then_success():
    state = {"n": 0}

    def transport(method, url, payload):
        state["n"] += 1
        if state["n"] < 3:
            raise ConnectionError("transient")
        return 200, _fake_scanner_payload()

    client = TradingViewClient(transport=transport, max_retries=3, backoff_base=0.0)
    rating = client.get_technical_rating("NASDAQ:AAPL")
    assert rating.recommendation == "BUY"
    assert state["n"] == 3


def test_retry_exhaustion_raises():
    def transport(method, url, payload):
        raise ConnectionError("always down")

    client = TradingViewClient(transport=transport, max_retries=2, backoff_base=0.0)
    with pytest.raises(TradingViewError):
        client.get_technical_rating("NASDAQ:AAPL")


def test_server_error_is_retried_then_raises():
    state = {"n": 0}

    def transport(method, url, payload):
        state["n"] += 1
        return 503, "unavailable"

    client = TradingViewClient(transport=transport, max_retries=2, backoff_base=0.0)
    with pytest.raises(TradingViewError):
        client.get_technical_rating("NASDAQ:AAPL")
    assert state["n"] == 3  # 1 initial + 2 retries


def test_client_error_not_retried():
    state = {"n": 0}

    def transport(method, url, payload):
        state["n"] += 1
        return 404, "not found"

    client = TradingViewClient(transport=transport, max_retries=3, backoff_base=0.0)
    with pytest.raises(TradingViewError):
        client.get_technical_rating("NASDAQ:AAPL")
    assert state["n"] == 1  # no retries on 4xx


def test_caching_avoids_second_request():
    state = {"n": 0}

    def transport(method, url, payload):
        state["n"] += 1
        return 200, _fake_scanner_payload()

    client = TradingViewClient(transport=transport, cache_ttl=3600)
    client.get_technical_rating("NASDAQ:AAPL")
    client.get_technical_rating("NASDAQ:AAPL")
    assert state["n"] == 1  # second call served from cache


def test_cache_disabled():
    state = {"n": 0}

    def transport(method, url, payload):
        state["n"] += 1
        return 200, _fake_scanner_payload()

    client = TradingViewClient(transport=transport, cache_ttl=0)
    client.get_technical_rating("NASDAQ:AAPL")
    client.get_technical_rating("NASDAQ:AAPL")
    assert state["n"] == 2


def test_parse_rating_bad_payload():
    client = TradingViewClient(transport=lambda m, u, p: (200, {}))
    with pytest.raises(TradingViewError):
        client.get_technical_rating("NASDAQ:AAPL")


def test_analyze_with_rating(ohlcv_candles):
    def transport(method, url, payload):
        return 200, _fake_scanner_payload()

    client = TradingViewClient(
        ohlcv_provider=_provider(ohlcv_candles), transport=transport
    )
    result = client.analyze(
        "NASDAQ:AAPL", timeframe="1d", limit=120, include_rating=True
    )
    assert result.rating is not None
    assert result.rating.recommendation == "BUY"