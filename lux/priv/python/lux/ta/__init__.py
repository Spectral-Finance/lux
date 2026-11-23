"""TradingView technical-analysis integration for Lux.

This subpackage provides a self-contained, dependency-light engine for
computing standard technical indicators over OHLCV candles and for retrieving
TradingView's aggregated technical ratings via the public screener/scan
endpoint.

Public surface
--------------
* :mod:`lux.ta.indicators` - pure indicator math (RSI, MACD, SMA/EMA, ...).
* :mod:`lux.ta.client`     - :class:`TradingViewClient` with retries, caching,
  typed responses and a signal-generation pipeline.

Example
-------
::

    from lux.ta import TradingViewClient

    def provider(symbol, timeframe, limit):
        return load_candles_from_somewhere(symbol, timeframe, limit)

    client = TradingViewClient(ohlcv_provider=provider)
    result = client.analyze("BINANCE:BTCUSDT", timeframe="1d")
    print(result.bias, result.signals)
"""

from .client import (
    AnalysisResult,
    Candle,
    TechnicalRating,
    TradingViewClient,
    TradingViewError,
    SCANNER_URL,
    DEFAULT_TIMEFRAMES,
)
from . import indicators
from .features import (
    Alert,
    AlertDialog,
    AlertManager,
    BacktestResult,
    TimeframeResult,
    backtest,
    multi_timeframe_analysis,
)

__all__ = [
    "TradingViewClient",
    "TradingViewError",
    "Candle",
    "TechnicalRating",
    "AnalysisResult",
    "SCANNER_URL",
    "DEFAULT_TIMEFRAMES",
    "indicators",
    "Alert",
    "AlertDialog",
    "AlertManager",
    "BacktestResult",
    "TimeframeResult",
    "backtest",
    "multi_timeframe_analysis",
]