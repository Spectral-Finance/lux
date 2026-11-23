"""Offline tests for multi-timeframe analysis, alerts and backtesting."""

import math
import os
import sys

import pytest

_HERE = os.path.dirname(os.path.abspath(__file__))
_PRIV_PYTHON = os.path.abspath(os.path.join(_HERE, "..", "..", "priv", "python"))
if _PRIV_PYTHON not in sys.path:
    sys.path.insert(0, _PRIV_PYTHON)

from lux.ta import indicators  # noqa: E402
from lux.ta.client import Candle, TradingViewClient  # noqa: E402
from lux.ta.features import (  # noqa: E402
    Alert,
    AlertDialog,
    AlertManager,
    BacktestResult,
    backtest,
    multi_timeframe_analysis,
)


def _uptrend_candles(n=120, start=100.0, step=0.5):
    candles = []
    price = start
    for i in range(n):
        open_ = price
        close = price + step
        high = max(open_, close) + 0.5
        low = min(open_, close) - 0.5
        candles.append(
            Candle(
                time=1_700_000_000 + i * 3600,
                open=open_,
                high=high,
                low=low,
                close=close,
                volume=1000.0,
            )
        )
        price = close
    return candles


def _provider(candles):
    return lambda symbol, timeframe, limit: candles[:limit]


# --------------------------------------------------------------------------- #
# Multi-timeframe analysis
# --------------------------------------------------------------------------- #
def test_multi_timeframe_consensus():
    candles = _uptrend_candles()
    client = TradingViewClient(ohlcv_provider=_provider(candles))
    result = multi_timeframe_analysis(
        client, "TEST:SYM", timeframes=("1d", "1h", "15m"), limit=120
    )
    assert result["symbol"] == "TEST:SYM"
    assert result["timeframes"] == ["1d", "1h", "15m"]
    assert len(result["results"]) == 3
    assert result["consensus"] in {"bullish", "bearish", "neutral"}
    # A persistent uptrend pushes RSI/price into overbought territory, so the
    # mean-reversion signals (RSI/seLL, above-Bollinger) dominate -> bearish.
    assert result["consensus"] == "bearish"


def test_multi_timeframe_votes_sum():
    candles = _uptrend_candles()
    client = TradingViewClient(ohlcv_provider=_provider(candles))
    result = multi_timeframe_analysis(client, "X", timeframes=("1d", "1h"), limit=120)
    assert sum(result["votes"].values()) == 2


# --------------------------------------------------------------------------- #
# Alerts
# --------------------------------------------------------------------------- #
def test_alert_above_threshold():
    dialog = AlertDialog(name="breakout", kind="above", threshold=105.0)
    candles = _uptrend_candles(n=20, start=100.0, step=1.0)
    alert = dialog.evaluate("TEST:SYM", candles)
    assert isinstance(alert, Alert)
    assert alert.value > 105.0


def test_alert_below_threshold_not_fired():
    dialog = AlertDialog(name="drop", kind="below", threshold=50.0)
    candles = _uptrend_candles(n=20, start=100.0, step=1.0)
    assert dialog.evaluate("TEST:SYM", candles) is None


def test_alert_rsi_above():
    # Strict uptrend -> RSI ~100 -> rsi_above(70) fires.
    dialog = AlertDialog(name="rsi_hot", kind="rsi_above", threshold=70.0, period=14)
    candles = _uptrend_candles(n=40, start=100.0, step=1.0)
    alert = dialog.evaluate("TEST:SYM", candles)
    assert alert is not None
    assert alert.value > 70.0


def test_alert_manager_evaluates_all():
    manager = AlertManager(
        [
            AlertDialog(name="a", kind="above", threshold=0.0),
            AlertDialog(name="b", kind="below", threshold=9999.0),
        ]
    )
    candles = _uptrend_candles(n=10)
    fired = manager.evaluate("TEST:SYM", candles)
    names = {a.rule for a in fired}
    assert "a" in names
    assert "b" in names


def test_alert_invalid_kind():
    dialog = AlertDialog(name="x", kind="bogus", threshold=1.0)
    with pytest.raises(ValueError):
        dialog.evaluate("SYM", _uptrend_candles(n=5))


# --------------------------------------------------------------------------- #
# Backtesting
# --------------------------------------------------------------------------- #
def test_backtest_profit_on_uptrend():
    candles = _uptrend_candles(n=100, start=100.0, step=1.0)

    # Simple rule: go long after the first 10 bars, stay long.
    def signal_fn(window):
        if len(window) >= 10:
            return 1
        return 0

    result = backtest("TEST:SYM", candles, signal_fn, initial_capital=10_000.0)
    assert isinstance(result, BacktestResult)
    assert result.trades >= 1
    # Strong uptrend -> profitable.
    assert result.final_capital > result.initial_capital
    assert result.total_return_pct > 0
    assert len(result.equity_curve) == len(candles)


def test_backtest_no_trades():
    candles = _uptrend_candles(n=20)
    result = backtest("SYM", candles, lambda w: 0)
    assert result.trades == 0
    assert result.final_capital == pytest.approx(result.initial_capital)
    assert result.win_rate_pct == 0.0


def test_backtest_empty_raises():
    with pytest.raises(ValueError):
        backtest("SYM", [], lambda w: 1)


def test_backtest_win_rate():
    candles = _uptrend_candles(n=60, start=100.0, step=1.0)

    def signal_fn(window):
        # Enter on bar 10, exit on bar 30, re-enter on bar 40.
        n = len(window)
        if n == 10 or n == 40:
            return 1
        if n == 30:
            return 0
        return None

    result = backtest("SYM", candles, signal_fn)
    assert result.trades >= 1
    assert 0.0 <= result.win_rate_pct <= 100.0