"""Top-level TradingView technical-analysis integration for Lux (issue #86).

This module is the convenience entrypoint for the TradingView TA integration.
It re-exports the public surface of :mod:`lux.ta` and adds a small
``analyze_symbol`` helper plus a ``__main__`` demo so the integration can be
run directly::

    python tradingview_ta.py            # runs an offline self-demo

The heavy lifting lives in :mod:`lux.ta.indicators` (pure indicator math) and
:mod:`lux.ta.client` (:class:`TradingViewClient` with retries, caching, typed
responses and signal generation).  Everything here is stdlib-only and performs
**no network I/O** unless a transport/provider is explicitly supplied.
"""

from __future__ import annotations

import os
import sys
from typing import List, Optional, Sequence

# Make ``lux`` importable when this file is executed directly from the repo root
# or from ``lux/priv/python``.
_HERE = os.path.dirname(os.path.abspath(__file__))
_PRIV_PYTHON = os.path.join(_HERE, "lux", "priv", "python")
if os.path.isdir(_PRIV_PYTHON) and _PRIV_PYTHON not in sys.path:
    sys.path.insert(0, _PRIV_PYTHON)

from lux.ta import (  # noqa: E402  (import after sys.path tweak)
    AnalysisResult,
    Candle,
    TechnicalRating,
    TradingViewClient,
    TradingViewError,
    DEFAULT_TIMEFRAMES,
    SCANNER_URL,
    indicators,
)

__all__ = [
    "TradingViewClient",
    "TradingViewError",
    "Candle",
    "TechnicalRating",
    "AnalysisResult",
    "DEFAULT_TIMEFRAMES",
    "SCANNER_URL",
    "indicators",
    "analyze_symbol",
    "demo",
]


def analyze_symbol(
    symbol: str,
    ohlcv_provider,
    timeframe: str = "1d",
    limit: int = 200,
    include_rating: bool = False,
    transport=None,
) -> AnalysisResult:
    """Convenience wrapper: build a client and analyze one symbol.

    Parameters
    ----------
    symbol:
        TradingView-style symbol, e.g. ``"BINANCE:BTCUSDT"``.
    ohlcv_provider:
        Callable ``provider(symbol, timeframe, limit) -> list[Candle | dict]``.
    timeframe:
        One of :data:`DEFAULT_TIMEFRAMES` (or any provider-supported value).
    limit:
        Number of candles to request.
    include_rating:
        When ``True`` also fetch TradingView's aggregated technical rating via
        the screener endpoint (requires ``transport`` or live network).
    transport:
        Optional HTTP transport ``(method, url, payload) -> (status, body)``.
    """
    client = TradingViewClient(
        ohlcv_provider=ohlcv_provider, transport=transport
    )
    return client.analyze(
        symbol, timeframe=timeframe, limit=limit, include_rating=include_rating
    )


def _synthetic_provider(symbol: str, timeframe: str, limit: int) -> List[Candle]:
    """Deterministic synthetic OHLCV series used by the offline demo/tests."""
    import math

    candles: List[Candle] = []
    price = 100.0
    for i in range(limit):
        # A sine wave plus a gentle uptrend -> deterministic, non-trivial data.
        drift = 0.05
        wave = math.sin(i / 5.0) * 2.0
        open_ = price
        close = price + drift + wave * 0.1
        high = max(open_, close) + abs(wave) * 0.5 + 0.2
        low = min(open_, close) - abs(wave) * 0.5 - 0.2
        volume = 1000.0 + (i % 7) * 50.0
        candles.append(
            Candle(
                time=1_700_000_000 + i * 86_400,
                open=open_,
                high=high,
                low=low,
                close=close,
                volume=volume,
            )
        )
        price = close
    return candles


def demo() -> AnalysisResult:
    """Run a fully offline demonstration and print a short report."""
    result = analyze_symbol(
        "SYNTHETIC:DEMO", _synthetic_provider, timeframe="1d", limit=200
    )
    print("TradingView TA integration — offline demo")
    print("=" * 48)
    print(f"Symbol        : {result.symbol}")
    print(f"Timeframe     : {result.timeframe}")
    print(f"Candles       : {result.candles}")
    print(f"Bias          : {result.bias}")
    print("Indicators (latest):")
    for key, value in result.indicators.items():
        if isinstance(value, float):
            print(f"  {key:<14}: {value:.4f}")
        else:
            print(f"  {key:<14}: {value}")
    print("Signals:")
    for sig in result.signals:
        print(f"  - {sig}")
    return result


if __name__ == "__main__":
    demo()