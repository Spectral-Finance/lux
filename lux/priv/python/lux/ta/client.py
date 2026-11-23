"""TradingView technical-analysis client.

This module provides :class:`TradingViewClient`, a small, dependency-light client
for retrieving market data and TradingView-style technical ratings.

Two complementary data sources are supported:

1. **OHLCV candles** - chart data for an arbitrary symbol/timeframe.  The client
   accepts candles either from an injected ``ohlcv_provider`` callable (so it can
   be wired to any exchange/data source inside Lux) or, when the optional
   ``requests`` dependency is present, from a pluggable HTTP backend.  The
   indicator engine (:mod:`lux.ta.indicators`) then computes real indicators
   over those candles.

2. **TradingView screener / scan endpoint** - the public
   ``scanner.tradingview.com`` "recommendation" scan that returns TradingView's
   aggregated technical rating (Strong Sell ... Strong Buy) for a symbol across
   multiple timeframes.  This mirrors the numbers shown on TradingView's
   *Technical Summary* gauge.

The client is intentionally transport-agnostic: all network access funnels
through a single ``_http_post`` / ``_http_get`` seam which tests replace with a
fake transport.  This keeps the whole module testable **fully offline**.

Features
--------
* Retries with exponential backoff + jitter for transient failures.
* A tiny in-process TTL cache keyed by request parameters.
* Typed response dataclasses (:class:`Candle`, :class:`TechnicalRating`,
  :class:`AnalysisResult`).
* Pure-stdlib implementation; ``requests`` is used only if already installed.
"""

from __future__ import annotations

import json
import random
import time
from dataclasses import dataclass, field
from typing import Callable, Dict, List, Optional, Sequence

from . import indicators

__all__ = [
    "Candle",
    "TechnicalRating",
    "AnalysisResult",
    "TradingViewError",
    "TradingViewClient",
    "SCANNER_URL",
    "DEFAULT_TIMEFRAMES",
]

#: Public TradingView screener/scan endpoint used for technical summaries.
SCANNER_URL = "https://scanner.tradingview.com/symbol"

#: Timeframes supported by TradingView's technical summary gauge.
DEFAULT_TIMEFRAMES = ("1d", "1h", "15m", "5m", "1m")


class TradingViewError(Exception):
    """Raised when the TradingView client cannot fulfil a request."""


@dataclass
class Candle:
    """A single OHLCV candle."""

    time: int
    open: float
    high: float
    low: float
    close: float
    volume: float = 0.0

    def to_dict(self) -> Dict[str, float]:
        return {
            "time": self.time,
            "open": self.open,
            "high": self.high,
            "low": self.low,
            "close": self.close,
            "volume": self.volume,
        }


@dataclass
class TechnicalRating:
    """Aggregated TradingView technical rating for one symbol/timeframe."""

    symbol: str
    timeframe: str
    recommendation: str  # STRONG_BUY / BUY / NEUTRAL / SELL / STRONG_SELL
    buy_count: int
    sell_count: int
    neutral_count: int
    summary: Dict[str, str] = field(default_factory=dict)

    @property
    def score(self) -> float:
        """Normalised score in ``[-1, 1]`` (1 == strongest buy)."""
        total = self.buy_count + self.sell_count + self.neutral_count
        if total == 0:
            return 0.0
        return (self.buy_count - self.sell_count) / total


@dataclass
class AnalysisResult:
    """Full technical-analysis result for a symbol over a candle series."""

    symbol: str
    timeframe: str
    candles: int
    indicators: Dict[str, object]
    signals: List[str]
    rating: Optional[TechnicalRating] = None

    @property
    def bias(self) -> str:
        """Aggregate directional bias derived from emitted signals."""
        buys = sum(1 for s in self.signals if s.endswith("_BUY"))
        sells = sum(1 for s in self.signals if s.endswith("_SELL"))
        if buys > sells:
            return "bullish"
        if sells > buys:
            return "bearish"
        return "neutral"


class _TTLCache:
    """A minimal thread-agnostic time-to-live cache."""

    def __init__(self, ttl_seconds: float) -> None:
        self.ttl = ttl_seconds
        self._store: Dict[str, tuple] = {}

    def get(self, key: str) -> Optional[object]:
        entry = self._store.get(key)
        if entry is None:
            return None
        value, expires_at = entry
        if time.time() >= expires_at:
            self._store.pop(key, None)
            return None
        return value

    def set(self, key: str, value: object) -> None:
        self._store[key] = (value, time.time() + self.ttl)

    def clear(self) -> None:
        self._store.clear()


class TradingViewClient:
    """Client for TradingView technical analysis.

    Parameters
    ----------
    ohlcv_provider:
        Optional callable ``provider(symbol, timeframe, limit) -> list[Candle]``
        (or list of dicts) used to source candles.  When supplied, no network
        access is required for :meth:`analyze`.
    transport:
        Optional callable ``transport(method, url, payload) -> (status, body)``
        used for the screener endpoint.  Tests inject a fake transport here.
    timeout:
        Per-request timeout in seconds (used by the default HTTP backend).
    max_retries:
        Number of retry attempts for transient failures.
    cache_ttl:
        Time-to-live (seconds) for cached responses.  ``0`` disables caching.
    backoff_base:
        Base delay (seconds) for exponential backoff between retries.
    session:
        Optional ``requests.Session``-compatible object.  If omitted and
        ``requests`` is importable, a module-level session is used lazily.
    """

    def __init__(
        self,
        ohlcv_provider: Optional[Callable[..., Sequence]] = None,
        transport: Optional[Callable[[str, str, dict], tuple]] = None,
        timeout: float = 10.0,
        max_retries: int = 3,
        cache_ttl: float = 60.0,
        backoff_base: float = 0.5,
        session: Optional[object] = None,
        user_agent: str = "lux-tradingview/1.0",
    ) -> None:
        self.ohlcv_provider = ohlcv_provider
        self.transport = transport
        self.timeout = timeout
        self.max_retries = max(0, int(max_retries))
        self.backoff_base = backoff_base
        self.session = session
        self.user_agent = user_agent
        self._cache = _TTLCache(cache_ttl)

    # ------------------------------------------------------------------ #
    # HTTP helpers (single seam, replaced in tests)
    # ------------------------------------------------------------------ #
    def _request_with_retries(self, method: str, url: str, payload: dict) -> dict:
        """Perform an HTTP request with retries + exponential backoff."""
        cache_key = f"{method}:{url}:{json.dumps(payload, sort_keys=True)}"
        cached = self._cache.get(cache_key)
        if cached is not None:
            return cached  # type: ignore[return-value]

        last_error: Optional[Exception] = None
        for attempt in range(self.max_retries + 1):
            try:
                status, body = self._raw_request(method, url, payload)
                if status >= 500:
                    # Server errors are transient -> retry.
                    raise ConnectionError(
                        f"server error {status} for {url}"
                    )
                if status >= 400:
                    # Client errors are not retried.
                    raise TradingViewError(
                        f"client error {status} for {url}: {body}"
                    )
                parsed = self._parse_body(body)
                self._cache.set(cache_key, parsed)
                return parsed
            except TradingViewError:
                raise
            except Exception as exc:  # noqa: BLE001 - transient -> retry
                last_error = exc
                if attempt < self.max_retries:
                    delay = self.backoff_base * (2 ** attempt)
                    delay += random.uniform(0, delay * 0.1)
                    time.sleep(delay)
                    continue
                break

        raise TradingViewError(
            f"request to {url} failed after {self.max_retries + 1} attempts: "
            f"{last_error}"
        )

    def _raw_request(self, method: str, url: str, payload: dict) -> tuple:
        """Low-level transport call returning ``(status_code, body)``."""
        if self.transport is not None:
            return self.transport(method, url, payload)

        # Default backend: use ``requests`` if available.
        try:
            import requests  # type: ignore
        except ImportError as exc:  # pragma: no cover - requests is a dep
            raise TradingViewError(
                "no transport configured and 'requests' is not installed"
            ) from exc

        session = self.session or requests
        headers = {"User-Agent": self.user_agent}
        if method.upper() == "POST":
            resp = session.post(
                url, json=payload, timeout=self.timeout, headers=headers
            )
        else:
            resp = session.get(url, timeout=self.timeout, headers=headers)
        return resp.status_code, resp.text

    @staticmethod
    def _parse_body(body) -> dict:
        if isinstance(body, (dict, list)):
            return body  # type: ignore[return-value]
        if isinstance(body, (bytes, bytearray)):
            body = body.decode("utf-8")
        return json.loads(body)

    # ------------------------------------------------------------------ #
    # Candle retrieval
    # ------------------------------------------------------------------ #
    @staticmethod
    def _coerce_candles(raw: Sequence) -> List[Candle]:
        candles: List[Candle] = []
        for item in raw:
            if isinstance(item, Candle):
                candles.append(item)
            elif isinstance(item, dict):
                candles.append(
                    Candle(
                        time=int(item.get("time", 0)),
                        open=float(item["open"]),
                        high=float(item["high"]),
                        low=float(item["low"]),
                        close=float(item["close"]),
                        volume=float(item.get("volume", 0.0) or 0.0),
                    )
                )
            else:  # sequence form: (time, open, high, low, close, volume)
                candles.append(
                    Candle(
                        time=int(item[0]),
                        open=float(item[1]),
                        high=float(item[2]),
                        low=float(item[3]),
                        close=float(item[4]),
                        volume=float(item[5]) if len(item) > 5 else 0.0,
                    )
                )
        return candles

    def get_ohlcv(
        self, symbol: str, timeframe: str = "1d", limit: int = 200
    ) -> List[Candle]:
        """Retrieve OHLCV candles for ``symbol``/``timeframe``.

        Requires an ``ohlcv_provider`` to have been supplied at construction.
        """
        if self.ohlcv_provider is None:
            raise TradingViewError(
                "no ohlcv_provider configured; pass one to the client to "
                "retrieve candles"
            )
        raw = self.ohlcv_provider(symbol, timeframe, limit)
        candles = self._coerce_candles(raw)
        if not candles:
            raise TradingViewError(
                f"ohlcv_provider returned no candles for {symbol} {timeframe}"
            )
        return candles

    # ------------------------------------------------------------------ #
    # TradingView screener / technical summary
    # ------------------------------------------------------------------ #
    def get_technical_rating(
        self, symbol: str, timeframe: str = "1d"
    ) -> TechnicalRating:
        """Fetch TradingView's aggregated technical rating for a symbol.

        ``symbol`` should be in TradingView ``EXCHANGE:TICKER`` form, e.g.
        ``"NASDAQ:AAPL"`` or ``"BINANCE:BTCUSDT"``.
        """
        payload = {
            "symbols": {"tickers": [symbol], "query": {"types": []}},
            "columns": ["Recommend.All", "Recommend.Other"],
        }
        url = f"{SCANNER_URL}/{symbol}"
        data = self._request_with_retries("POST", url, payload)
        return self._parse_rating(symbol, timeframe, data)

    @staticmethod
    def _parse_rating(
        symbol: str, timeframe: str, data: dict
    ) -> TechnicalRating:
        try:
            total = data["totalCount"]
            rows = data["data"]
            row = rows[0]
            values = row["d"]
        except (KeyError, IndexError, TypeError) as exc:
            raise TradingViewError(
                f"unexpected scanner payload for {symbol}: {exc}"
            ) from exc

        # Recommend.All is a numeric aggregate: 1 == strong sell, 0.5 == sell,
        # 0 == neutral, -0.5 == buy, -1 == strong buy (TradingView convention).
        recommend_all = values[0]
        mapping = {
            1.0: "STRONG_SELL",
            0.5: "SELL",
            0.0: "NEUTRAL",
            -0.5: "BUY",
            -1.0: "STRONG_BUY",
        }
        recommendation = mapping.get(
            round(float(recommend_all), 4), "NEUTRAL"
        )

        # Derive buy/sell/neutral counts from the two columns when available.
        buy_count = sell_count = neutral_count = 0
        if len(values) > 1 and isinstance(values[1], dict):
            other = values[1]
            buy_count = int(other.get("COMPUTE", {}).get("Bullish", 0) or 0)
            sell_count = int(other.get("COMPUTE", {}).get("Bearish", 0) or 0)
            neutral_count = max(
                0, total - buy_count - sell_count
            )

        return TechnicalRating(
            symbol=symbol,
            timeframe=timeframe,
            recommendation=recommendation,
            buy_count=buy_count,
            sell_count=sell_count,
            neutral_count=neutral_count,
            summary={"recommend_all": recommend_all, "total": total},
        )

    # ------------------------------------------------------------------ #
    # Indicator + signal engine
    # ------------------------------------------------------------------ #
    def compute_indicators(
        self, candles: Sequence[Candle]
    ) -> Dict[str, object]:
        """Compute the full indicator set over ``candles``."""
        closes = [c.close for c in candles]
        highs = [c.high for c in candles]
        lows = [c.low for c in candles]
        volumes = [c.volume for c in candles]

        def _last(seq):
            for value in reversed(seq):
                if value is not None:
                    return value
            return None

        macd = indicators.macd(closes)
        bb = indicators.bollinger_bands(closes)
        stoch = indicators.stochastic(highs, lows, closes)

        return {
            "sma_20": _last(indicators.sma(closes, 20)),
            "sma_50": _last(indicators.sma(closes, 50)),
            "ema_12": _last(indicators.ema(closes, 12)),
            "ema_26": _last(indicators.ema(closes, 26)),
            "rsi_14": _last(indicators.rsi(closes, 14)),
            "macd": _last(macd["macd"]),
            "macd_signal": _last(macd["signal"]),
            "macd_histogram": _last(macd["histogram"]),
            "bb_upper": _last(bb["upper"]),
            "bb_middle": _last(bb["middle"]),
            "bb_lower": _last(bb["lower"]),
            "stoch_k": _last(stoch["k"]),
            "stoch_d": _last(stoch["d"]),
            "atr_14": _last(indicators.atr(highs, lows, closes, 14)),
            "obv": _last(indicators.obv(closes, volumes)),
            "vwap": _last(indicators.vwap(highs, lows, closes, volumes)),
            "close": closes[-1] if closes else None,
        }

    def generate_signals(self, ind: Dict[str, object]) -> List[str]:
        """Translate an indicator snapshot into a list of signal strings.

        Each signal is an upper-case identifier suffixed with ``_BUY`` or
        ``_SELL`` so downstream consumers can aggregate directional bias.
        """
        signals: List[str] = []

        rsi = ind.get("rsi_14")
        if rsi is not None:
            if rsi < 30:
                signals.append("RSI_OVERSOLD_BUY")
            elif rsi > 70:
                signals.append("RSI_OVERBOUGHT_SELL")

        macd = ind.get("macd")
        macd_signal = ind.get("macd_signal")
        if macd is not None and macd_signal is not None:
            if macd > macd_signal:
                signals.append("MACD_BULLISH_BUY")
            elif macd < macd_signal:
                signals.append("MACD_BEARISH_SELL")

        close = ind.get("close")
        sma50 = ind.get("sma_50")
        if close is not None and sma50 is not None:
            if close > sma50:
                signals.append("PRICE_ABOVE_SMA50_BUY")
            else:
                signals.append("PRICE_BELOW_SMA50_SELL")

        bb_upper = ind.get("bb_upper")
        bb_lower = ind.get("bb_lower")
        if close is not None and bb_upper is not None and bb_lower is not None:
            if close < bb_lower:
                signals.append("BELOW_BOLLINGER_BUY")
            elif close > bb_upper:
                signals.append("ABOVE_BOLLINGER_SELL")

        stoch_k = ind.get("stoch_k")
        if stoch_k is not None:
            if stoch_k < 20:
                signals.append("STOCHASTIC_OVERSOLD_BUY")
            elif stoch_k > 80:
                signals.append("STOCHASTIC_OVERBOUGHT_SELL")

        return signals

    def analyze(
        self,
        symbol: str,
        timeframe: str = "1d",
        limit: int = 200,
        include_rating: bool = False,
    ) -> AnalysisResult:
        """Run the full pipeline: candles -> indicators -> signals (-> rating)."""
        candles = self.get_ohlcv(symbol, timeframe, limit)
        ind = self.compute_indicators(candles)
        signals = self.generate_signals(ind)

        rating: Optional[TechnicalRating] = None
        if include_rating:
            rating = self.get_technical_rating(symbol, timeframe)

        return AnalysisResult(
            symbol=symbol,
            timeframe=timeframe,
            candles=len(candles),
            indicators=ind,
            signals=signals,
            rating=rating,
        )