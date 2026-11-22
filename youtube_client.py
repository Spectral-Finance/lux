"""
YouTube Data API v3 client + content-intelligence integration layer
(Spectral-Finance/lux issue #76).

This module is the **I/O half** of the YouTube Prism architecture. The prisms in
:mod:`youtube_prisms` are pure decision units; this client is responsible for the
impure part -- talking to the YouTube Data API v3 -- and then handing the parsed
JSON payloads to the prisms.

Design
------
* **Stdlib only.** Uses :mod:`urllib.request` / :mod:`urllib.parse`; no
  third-party dependency (no ``google-api-python-client``). This keeps the
  client droppable into the lux monorepo without adding to its dependency tree.
* **Production-grade transport.** The client ships the same operational
  primitives the rest of the lux Prism suite relies on:
    - **Quota accounting** (:class:`QuotaLimiter`) -- YouTube's Data API is
      governed by a *daily unit quota* (default 10,000 units); every call is
      charged its documented unit cost up-front and a :class:`QuotaExceededError`
      is raised before the budget is blown.
    - **Rate limiting** (:class:`RateLimiter`) -- a per-route token bucket that
      smooths short bursts and drains on ``Retry-After``.
    - **Retry with backoff** -- exponential backoff + jitter for 429/5xx,
      honouring the ``Retry-After`` header.
    - **Event emission** (:class:`EventEmitter`) -- every request emits a
      structured ``request`` event so callers can observe quota/latency.
    - **Typed exceptions** -- :class:`NotFoundError`, :class:`ForbiddenError`,
      :class:`QuotaExceededError`, :class:`RateLimitedError`,
      :class:`ServerError`, :class:`YouTubeAPIError`.
    - **Injectable transport + sleep** -- ``transport`` and ``sleep_fn`` are
      injectable so the whole retry/quota/rate-limit machinery is unit-testable
      with **zero network access**.
* **Thin prisms boundary.** Every public ``get_*`` method returns the raw parsed
  ``dict``; every ``analyze_*`` method delegates the *decision* to a prism so
  the intelligence logic stays pure and offline-testable.
* **Explicit auth.** The API key comes from the ``YOUTUBE_API_KEY`` environment
  variable or an explicit ``api_key`` argument. The key is never logged.

The pure-logic surface (quota accounting, rate-limit math, retry/backoff,
param building, prism delegation) is exercised by
``test_youtube_prisms_impl.py`` without any network access.
"""

from __future__ import annotations

import json
import os
import random
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from typing import Any, Callable, Dict, List, Optional

from youtube_prisms import (
    ChannelBenchmarkPrism,
    ChannelGrowthPrism,
    ContentGapPrism,
    PrismResult,
    RevenueEstimatePrism,
    SeoAuditPrism,
    TrendingTopicsPrism,
    VideoMetadataPrism,
    VideoPerformancePrism,
    build_registry,
)

__all__ = [
    "YouTubeClient",
    "YouTubeAPIError",
    "NotFoundError",
    "ForbiddenError",
    "QuotaExceededError",
    "RateLimitedError",
    "ServerError",
    "RateLimiter",
    "QuotaLimiter",
    "EventEmitter",
]

_YOUTUBE_API_BASE = "https://www.googleapis.com/youtube/v3"
_DEFAULT_TIMEOUT = 15.0


# ---------------------------------------------------------------------------
# Typed exceptions
# ---------------------------------------------------------------------------
class YouTubeAPIError(RuntimeError):
    """Base error for every YouTube Data API failure."""

    def __init__(self, message: str, status: int = 0, body: Any = None) -> None:
        super().__init__(message)
        self.message = message
        self.status = status
        self.body = body


class NotFoundError(YouTubeAPIError):
    """404 -- the requested resource (video, channel, playlist) does not exist."""


class ForbiddenError(YouTubeAPIError):
    """403 -- the API key / OAuth token lacks permission for this operation."""


class QuotaExceededError(YouTubeAPIError):
    """Daily quota exhausted (or a 403 quotaExceeded response from YouTube)."""

    def __init__(self, message: str = "daily quota exceeded", body: Any = None) -> None:
        super().__init__(message, status=403, body=body)


class RateLimitedError(YouTubeAPIError):
    """429 -- too many requests; retry after ``retry_after`` seconds."""

    def __init__(self, message: str = "rate limited", retry_after: float = 0.0,
                 body: Any = None) -> None:
        super().__init__(message, status=429, body=body)
        self.retry_after = retry_after


class ServerError(YouTubeAPIError):
    """5xx -- YouTube-side transient failure."""


# ---------------------------------------------------------------------------
# Rate limiter -- per-route token bucket (short-term burst control)
# ---------------------------------------------------------------------------
@dataclass
class _Bucket:
    tokens: float
    capacity: float
    refill_per_sec: float
    updated_at: float = field(default_factory=time.monotonic)


class RateLimiter:
    """A thread-safe, per-route token-bucket rate limiter.

    YouTube does not expose per-second rate-limit headers the way Discord does,
    but short bursts still trigger 429s. We keep a local bucket per route and
    proactively pause when YouTube tells us to via ``Retry-After``.
    """

    DEFAULT_CAPACITY = 100.0
    DEFAULT_REFILL = 50.0  # tokens / second

    def __init__(self, capacity: float = DEFAULT_CAPACITY,
                 refill: float = DEFAULT_REFILL) -> None:
        self._buckets: Dict[str, _Bucket] = {}
        self._lock = threading.Lock()
        self._capacity = capacity
        self._refill = refill

    def _bucket(self, route: str) -> _Bucket:
        b = self._buckets.get(route)
        if b is None:
            b = _Bucket(tokens=self._capacity, capacity=self._capacity,
                        refill_per_sec=self._refill)
            self._buckets[route] = b
        return b

    def acquire(self, route: str, tokens: float = 1.0,
                sleep_fn: Callable[[float], None] = time.sleep) -> float:
        """Block until ``tokens`` are available for ``route``; return wait secs."""
        waited = 0.0
        while True:
            with self._lock:
                now = time.monotonic()
                b = self._bucket(route)
                elapsed = now - b.updated_at
                b.updated_at = now
                b.tokens = min(b.capacity, b.tokens + elapsed * b.refill_per_sec)
                if b.tokens >= tokens:
                    b.tokens -= tokens
                    return waited
                deficit = tokens - b.tokens
                wait = deficit / b.refill_per_sec if b.refill_per_sec else 0.05
            sleep_fn(wait)
            waited += wait

    def pause(self, route: str, seconds: float) -> None:
        """Drain the bucket for ``route`` to force a pause of ``seconds``."""
        with self._lock:
            b = self._bucket(route)
            b.tokens = 0.0
            b.updated_at = time.monotonic() + max(0.0, seconds)


# ---------------------------------------------------------------------------
# Quota limiter -- daily unit budget (YouTube Data API quota model)
# ---------------------------------------------------------------------------
class QuotaLimiter:
    """Tracks a daily unit budget against YouTube's quota model.

    Every Data API call has a documented *unit cost* (e.g. a ``videos.list`` is
    1 unit, a ``search.list`` is 100 units). The default daily quota is 10,000
    units. This limiter accumulates cost and raises :class:`QuotaExceededError`
    once the budget is spent, optionally resetting on a new UTC day.
    """

    def __init__(self, daily_limit: int = 10000,
                 clock: Callable[[], float] = time.time) -> None:
        self.daily_limit = daily_limit
        self._clock = clock
        self._used = 0
        self._day = self._today()
        self._lock = threading.Lock()

    def _today(self) -> int:
        return int(self._clock() // 86400)

    def _maybe_reset(self) -> None:
        today = self._today()
        if today != self._day:
            self._day = today
            self._used = 0

    def remaining(self) -> int:
        with self._lock:
            self._maybe_reset()
            return max(0, self.daily_limit - self._used)

    def used(self) -> int:
        with self._lock:
            self._maybe_reset()
            return self._used

    def charge(self, units: int) -> int:
        """Charge ``units`` against the budget; return remaining. Raises if over."""
        with self._lock:
            self._maybe_reset()
            if units < 0:
                raise ValueError("units must be non-negative")
            if self._used + units > self.daily_limit:
                raise QuotaExceededError(
                    "quota exceeded: %d+%d > %d"
                    % (self._used, units, self.daily_limit)
                )
            self._used += units
            return self.daily_limit - self._used


# ---------------------------------------------------------------------------
# Event emitter -- lightweight synchronous pub/sub
# ---------------------------------------------------------------------------
class EventEmitter:
    """Minimal synchronous event bus. Listeners are called in registration
    order; a failing listener is isolated so it cannot break the emitter."""

    def __init__(self) -> None:
        self._listeners: Dict[str, List[Callable[..., None]]] = {}
        self._lock = threading.Lock()

    def on(self, event: str, handler: Callable[..., None]) -> Callable[..., None]:
        with self._lock:
            self._listeners.setdefault(event, []).append(handler)
        return handler

    def off(self, event: str, handler: Callable[..., None]) -> None:
        with self._lock:
            if event in self._listeners:
                self._listeners[event] = [
                    h for h in self._listeners[event] if h is not handler
                ]

    def emit(self, event: str, **kwargs: Any) -> None:
        with self._lock:
            handlers = list(self._listeners.get(event, []))
        for h in handlers:
            try:
                h(**kwargs)
            except Exception:  # noqa: BLE001 - isolate listener failures
                pass


# ---------------------------------------------------------------------------
# Client
# ---------------------------------------------------------------------------
class YouTubeClient:
    """A production-grade YouTube Data API v3 client with intelligence helpers.

    Parameters
    ----------
    api_key:
        YouTube Data API v3 key. Falls back to the ``YOUTUBE_API_KEY``
        environment variable when omitted.
    quota:
        Optional :class:`QuotaLimiter`. When supplied, every call is charged its
        documented unit cost before the request is made.
    limiter:
        Optional :class:`RateLimiter` (a default one is created when omitted).
    transport:
        Injectable callable ``fn(method, url, headers, body) ->
        (status, headers, body_bytes)`` so unit tests never hit the network.
    sleep_fn:
        Injectable sleep so retry/rate-limit tests run instantly.
    max_retries:
        How many times to retry a 429/5xx before giving up.
    """

    #: Documented unit costs for the endpoints we use.
    COSTS = {
        "videos": 1,
        "channels": 1,
        "search": 100,
        "playlistItems": 1,
    }

    def __init__(
        self,
        api_key: Optional[str] = None,
        timeout: float = _DEFAULT_TIMEOUT,
        quota: Optional[QuotaLimiter] = None,
        limiter: Optional[RateLimiter] = None,
        transport: Optional[Callable] = None,
        sleep_fn: Callable[[float], None] = time.sleep,
        max_retries: int = 4,
        events: Optional[EventEmitter] = None,
    ) -> None:
        self._api_key = api_key or os.environ.get("YOUTUBE_API_KEY", "")
        self.timeout = timeout
        self.quota = quota
        self.limiter = limiter or RateLimiter()
        self.max_retries = max_retries
        self.events = events or EventEmitter()
        self._transport = transport or self._urllib_transport
        self._sleep = sleep_fn
        # A registry of the pure prisms, available for callers that want
        # name-based dispatch without wiring the prisms themselves.
        self.prisms = build_registry()

    # -- pure helpers (no network) ----------------------------------------
    def resolve_api_key(self) -> str:
        if not self._api_key:
            raise YouTubeAPIError("missing API key (set YOUTUBE_API_KEY)", status=401)
        return self._api_key

    @staticmethod
    def _build_params(params: Dict[str, Any], api_key: str) -> Dict[str, str]:
        """Merge caller params with the API key into a query string dict.

        ``None`` values are dropped so callers can pass optional filters
        without special-casing them.
        """
        merged: Dict[str, str] = {"key": api_key}
        for key, value in params.items():
            if value is None:
                continue
            if isinstance(value, bool):
                merged[key] = "true" if value else "false"
            elif isinstance(value, (list, tuple)):
                merged[key] = ",".join(str(v) for v in value)
            else:
                merged[key] = str(value)
        return merged

    def _cost(self, endpoint: str) -> int:
        return self.COSTS.get(endpoint, 1)

    # -- transport (the only method that touches the network) -------------
    @staticmethod
    def _urllib_transport(method, url, headers, body):
        req = urllib.request.Request(url, data=body, method=method)
        for k, v in headers.items():
            req.add_header(k, v)
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                return resp.status, dict(resp.headers), resp.read()
        except urllib.error.HTTPError as exc:
            return exc.code, dict(exc.headers or {}), exc.read()

    def _request(self, endpoint: str, params: Dict[str, Any]) -> Dict[str, Any]:
        """Execute a rate-limited, quota-charged, retry-aware API request."""
        query = self._build_params(params, self.resolve_api_key())
        url = "%s/%s?%s" % (
            _YOUTUBE_API_BASE,
            endpoint,
            urllib.parse.urlencode(query),
        )
        headers = {"Accept": "application/json"}

        # Charge quota up-front (fail fast if the budget is gone).
        if self.quota is not None:
            self.quota.charge(self._cost(endpoint))

        route = "GET %s" % endpoint
        attempt = 0
        while True:
            self.limiter.acquire(route, sleep_fn=self._sleep)
            self.events.emit(
                "request",
                endpoint=endpoint,
                attempt=attempt,
                quota_remaining=(self.quota.remaining() if self.quota else None),
            )
            status, resp_headers, resp_body = self._transport(
                "GET", url, headers, None
            )

            if status == 429:
                retry_after = self._retry_after(resp_headers, resp_body)
                self.limiter.pause(route, retry_after)
                if attempt >= self.max_retries:
                    raise RateLimitedError(
                        "rate limited after %d retries" % attempt,
                        retry_after=retry_after,
                    )
                self._sleep(retry_after)
                attempt += 1
                continue

            if status >= 500:
                if attempt >= self.max_retries:
                    raise ServerError(
                        "server error %d" % status, status=status
                    )
                backoff = self._backoff(attempt)
                self._sleep(backoff)
                attempt += 1
                continue

            return self._handle(status, resp_body)

    @staticmethod
    def _retry_after(headers: Dict[str, str], body: bytes) -> float:
        ra = headers.get("Retry-After") or headers.get("retry-after")
        if ra:
            try:
                return float(ra)
            except (TypeError, ValueError):
                pass
        try:
            data = json.loads(body or b"{}")
            return float(data.get("retry_after", 1.0))
        except (json.JSONDecodeError, ValueError, TypeError):
            return 1.0

    @staticmethod
    def _backoff(attempt: int) -> float:
        return (2 ** attempt) + random.uniform(0, 0.5)

    @staticmethod
    def _handle(status: int, body: bytes) -> Dict[str, Any]:
        try:
            data = json.loads(body) if body else {}
        except json.JSONDecodeError:
            data = {"raw": body.decode(errors="replace")}
        if status == 204 or not body:
            return {}
        if status == 404:
            raise NotFoundError("resource not found", status=404, body=data)
        if status == 403:
            reason = ""
            if isinstance(data, dict):
                err = data.get("error", {})
                if isinstance(err, dict):
                    errors = err.get("errors", [])
                    if errors and isinstance(errors[0], dict):
                        reason = errors[0].get("reason", "")
            if reason in ("quotaExceeded", "dailyLimitExceeded", "rateLimitExceeded"):
                raise QuotaExceededError(body=data)
            raise ForbiddenError("forbidden", status=403, body=data)
        if status >= 400:
            msg = (
                data.get("error", {}).get("message")
                if isinstance(data, dict) and isinstance(data.get("error"), dict)
                else "HTTP %d" % status
            )
            raise YouTubeAPIError(msg or ("HTTP %d" % status), status=status, body=data)
        return data

    # -- raw resource fetchers (return parsed dicts) ----------------------
    def get_video(self, video_id: str, part: str = "snippet,statistics,contentDetails") -> Dict[str, Any]:
        data = self._request("videos", {"id": video_id, "part": part})
        items = data.get("items") or []
        return items[0] if items else {}

    def get_videos(self, video_ids: List[str], part: str = "snippet,statistics,contentDetails") -> List[Dict[str, Any]]:
        if not video_ids:
            return []
        data = self._request("videos", {"id": video_ids, "part": part})
        return list(data.get("items") or [])

    def search_videos(self, query: str, max_results: int = 10) -> List[Dict[str, Any]]:
        data = self._request(
            "search",
            {"q": query, "part": "snippet", "type": "video", "maxResults": max_results},
        )
        return list(data.get("items") or [])

    def get_channel(self, channel_id: str, part: str = "snippet,statistics,contentDetails") -> Dict[str, Any]:
        data = self._request("channels", {"id": channel_id, "part": part})
        items = data.get("items") or []
        return items[0] if items else {}

    def get_channel_by_username(self, username: str, part: str = "snippet,statistics,contentDetails") -> Dict[str, Any]:
        data = self._request("channels", {"forUsername": username, "part": part})
        items = data.get("items") or []
        return items[0] if items else {}

    def get_channel_uploads(self, channel_id: str, max_results: int = 50) -> List[Dict[str, Any]]:
        channel = self.get_channel(channel_id, part="contentDetails")
        uploads = (
            (channel.get("contentDetails") or {}).get("relatedPlaylists", {}) or {}
        ).get("uploads")
        if not uploads:
            return []
        data = self._request(
            "playlistItems",
            {"playlistId": uploads, "part": "contentDetails", "maxResults": max_results},
        )
        ids = [
            (item.get("contentDetails") or {}).get("videoId")
            for item in (data.get("items") or [])
            if (item.get("contentDetails") or {}).get("videoId")
        ]
        return self.get_videos(ids) if ids else []

    # -- content-intelligence helpers (delegate to prisms) ----------------
    def analyze_video_performance(self, video: Dict[str, Any]) -> PrismResult:
        """Run the :class:`VideoPerformancePrism` on a video resource."""
        return VideoPerformancePrism().run({"video": video})

    def extract_video_metadata(self, video: Dict[str, Any]) -> PrismResult:
        """Run the :class:`VideoMetadataPrism` on a video resource."""
        return VideoMetadataPrism().run({"video": video})

    def analyze_channel_growth(self, channel: Dict[str, Any]) -> PrismResult:
        """Run the :class:`ChannelGrowthPrism` on a channel resource."""
        return ChannelGrowthPrism().run({"channel": channel})

    def benchmark_channel(self, channel: Dict[str, Any], peers: List[Dict[str, Any]]) -> PrismResult:
        """Run the :class:`ChannelBenchmarkPrism` against peer channels."""
        return ChannelBenchmarkPrism().run({"channel": channel, "peers": peers})

    def trending_topics(self, videos: List[Dict[str, Any]], limit: int = 10) -> PrismResult:
        """Run the :class:`TrendingTopicsPrism` over a batch of videos."""
        return TrendingTopicsPrism().run({"videos": videos, "limit": limit})

    def content_gaps(self, covered: List[str], targets: List[Any]) -> PrismResult:
        """Run the :class:`ContentGapPrism` for a channel's coverage vs targets."""
        return ContentGapPrism().run({"covered": covered, "targets": targets})

    def estimate_revenue(self, views: int, cpm_low: float = 1.0, cpm_high: float = 5.0) -> PrismResult:
        """Run the :class:`RevenueEstimatePrism` for a view count."""
        return RevenueEstimatePrism().run(
            {"views": views, "cpm_low": cpm_low, "cpm_high": cpm_high}
        )

    def audit_seo(self, snippet: Dict[str, Any], target_keyword: str = "") -> PrismResult:
        """Run the :class:`SeoAuditPrism` on a video snippet."""
        return SeoAuditPrism().run({"snippet": snippet, "target_keyword": target_keyword})