"""
youtube_intel — Core primitives for the Spectral-Finance/lux YouTube Content
Intelligence System (issue #69).

This module provides the shared, production-grade core that every intelligence
component (analytics, models, optimizer) builds on:

  * YouTube Data API client — a thin ``urllib`` wrapper (``YouTubeClient``) with
    an injectable transport so unit tests never touch the network.
  * Quota-aware rate limiting — YouTube's Data API is governed by a *daily quota*
    (default 10,000 units). ``QuotaLimiter`` tracks unit cost per call and blocks
    (or raises) when the budget is exhausted, in addition to a per-route token
    bucket for short-term bursts.
  * Retry with backoff — exponential backoff + jitter for 429/5xx, honouring the
    ``Retry-After`` header.
  * Event emission — a lightweight synchronous event bus so every operation emits
    a structured event.
  * State persistence — pluggable persistence hook (in-memory by default, JSON
    file for durable state).
  * Error handling — typed exceptions (``NotFoundError``, ``ForbiddenError``,
    ``QuotaExceededError``, ``RateLimitedError``, ``ServerError``,
    ``YouTubeAPIError``).

The module is dependency-free (stdlib only) so it drops into the lux monorepo
without adding transitive dependencies.
"""

from __future__ import annotations

import json
import random
import threading
import time
from dataclasses import dataclass, field
from typing import Any, Callable, Dict, List, Optional

__all__ = [
    "YouTubeAPIError",
    "NotFoundError",
    "ForbiddenError",
    "QuotaExceededError",
    "RateLimitedError",
    "ServerError",
    "RateLimiter",
    "QuotaLimiter",
    "EventEmitter",
    "YouTubeClient",
    "InMemoryPersistence",
    "JsonFilePersistence",
]


# --------------------------------------------------------------------------- #
# Errors
# --------------------------------------------------------------------------- #
class YouTubeAPIError(Exception):
    """Base error for every YouTube Data API failure."""

    def __init__(self, message: str, status: Optional[int] = None,
                 payload: Optional[Dict[str, Any]] = None):
        super().__init__(message)
        self.message = message
        self.status = status
        self.payload = payload or {}


class NotFoundError(YouTubeAPIError):
    """404 — the requested resource (video, channel, playlist) does not exist."""


class ForbiddenError(YouTubeAPIError):
    """403 — the API key / OAuth token lacks permission for this operation."""


class QuotaExceededError(YouTubeAPIError):
    """Daily quota exhausted (or a 403 quotaExceeded response from YouTube)."""

    def __init__(self, message: str = "daily quota exceeded",
                 payload: Optional[Dict[str, Any]] = None):
        super().__init__(message, status=403, payload=payload)


class RateLimitedError(YouTubeAPIError):
    """429 — too many requests; retry after ``retry_after`` seconds."""

    def __init__(self, message: str, retry_after: float = 0.0,
                 payload: Optional[Dict[str, Any]] = None):
        super().__init__(message, status=429, payload=payload)
        self.retry_after = retry_after


class ServerError(YouTubeAPIError):
    """5xx — YouTube-side transient failure."""


# --------------------------------------------------------------------------- #
# Rate limiter — per-route token bucket (short-term burst control)
# --------------------------------------------------------------------------- #
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

    def acquire(self, route: str, tokens: float = 1.0) -> float:
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
            time.sleep(wait)
            waited += wait

    def pause(self, route: str, seconds: float) -> None:
        """Drain the bucket for ``route`` to force a pause of ``seconds``."""
        with self._lock:
            b = self._bucket(route)
            b.tokens = 0.0
            b.updated_at = time.monotonic() + max(0.0, seconds)


# --------------------------------------------------------------------------- #
# Quota limiter — daily unit budget (YouTube Data API quota model)
# --------------------------------------------------------------------------- #
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
                    f"quota exceeded: {self._used}+{units} > {self.daily_limit}")
            self._used += units
            return self.daily_limit - self._used


# --------------------------------------------------------------------------- #
# Event emitter — lightweight synchronous pub/sub
# --------------------------------------------------------------------------- #
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


# --------------------------------------------------------------------------- #
# Persistence — pluggable state store
# --------------------------------------------------------------------------- #
class InMemoryPersistence:
    """Default persistence backend: a process-local dict."""

    def __init__(self) -> None:
        self._data: Dict[str, Any] = {}
        self._lock = threading.Lock()

    def get(self, key: str, default: Any = None) -> Any:
        with self._lock:
            return self._data.get(key, default)

    def set(self, key: str, value: Any) -> None:
        with self._lock:
            self._data[key] = value

    def delete(self, key: str) -> None:
        with self._lock:
            self._data.pop(key, None)

    def all(self) -> Dict[str, Any]:
        with self._lock:
            return dict(self._data)


class JsonFilePersistence(InMemoryPersistence):
    """JSON-file persistence for durable state across restarts."""

    def __init__(self, path: str) -> None:
        super().__init__()
        self._path = path
        self._load()

    def _load(self) -> None:
        try:
            with open(self._path, "r", encoding="utf-8") as fh:
                self._data = json.load(fh)
        except (OSError, json.JSONDecodeError):
            self._data = {}

    def _flush(self) -> None:
        tmp = self._path + ".tmp"
        try:
            with open(tmp, "w", encoding="utf-8") as fh:
                json.dump(self._data, fh)
            import os
            os.replace(tmp, self._path)
        except OSError:
            pass

    def set(self, key: str, value: Any) -> None:
        super().set(key, value)
        self._flush()

    def delete(self, key: str) -> None:
        super().delete(key)
        self._flush()


# --------------------------------------------------------------------------- #
# HTTP client — thin urllib wrapper with retry + quota + rate limiting
# --------------------------------------------------------------------------- #
class YouTubeClient:
    """Minimal YouTube Data API v3 client (stdlib urllib).

    Parameters
    ----------
    api_key:
        YouTube Data API key (sent as ``key`` query param). Never logged.
    quota:
        Optional :class:`QuotaLimiter`. When supplied, every call is charged its
        documented unit cost before the request is made.
    transport:
        Injectable callable ``fn(method, url, headers, body) ->
        (status, headers, body_bytes)`` so unit tests never hit the network.
    sleep_fn:
        Injectable sleep so retry tests run instantly.
    """

    API_BASE = "https://www.googleapis.com/youtube/v3"

    #: Documented unit costs for the endpoints we use.
    COSTS = {
        "videos.list": 1,
        "channels.list": 1,
        "search.list": 100,
        "playlistItems.list": 1,
        "commentThreads.list": 1,
        "videos.insert": 1600,
        "videos.update": 50,
    }

    def __init__(self, api_key: str = "",
                 limiter: Optional[RateLimiter] = None,
                 quota: Optional[QuotaLimiter] = None,
                 max_retries: int = 5,
                 transport: Optional[Callable] = None,
                 sleep_fn: Callable[[float], None] = time.sleep) -> None:
        self.api_key = api_key
        self.limiter = limiter or RateLimiter()
        self.quota = quota
        self.max_retries = max_retries
        self._transport = transport or self._urllib_transport
        self._sleep = sleep_fn

    @staticmethod
    def _urllib_transport(method, url, headers, body):
        import urllib.request
        import urllib.error
        req = urllib.request.Request(url, data=body, method=method)
        for k, v in headers.items():
            req.add_header(k, v)
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                return resp.status, dict(resp.headers), resp.read()
        except urllib.error.HTTPError as e:
            return e.code, dict(e.headers or {}), e.read()

    def _cost(self, resource: str) -> int:
        return self.COSTS.get(resource, 1)

    def request(self, method: str, resource: str,
                params: Optional[Dict[str, Any]] = None,
                json_body: Optional[Dict[str, Any]] = None) -> Any:
        """Perform an API request against ``resource`` (e.g. ``videos.list``).

        ``resource`` is ``"<endpoint>.<method>"`` and is used both to build the
        URL path and to look up the quota cost.
        """
        endpoint = resource.split(".")[0]
        path = f"/{endpoint}"
        query: Dict[str, Any] = dict(params or {})
        if self.api_key:
            query.setdefault("key", self.api_key)
        url = self.API_BASE + path
        if query:
            import urllib.parse
            url += "?" + urllib.parse.urlencode(
                {k: v for k, v in query.items() if v is not None})

        body = json.dumps(json_body).encode() if json_body is not None else None
        headers = {"User-Agent": "youtube-intel (lux, 1.0)"}
        if body is not None:
            headers["Content-Type"] = "application/json"

        # Charge quota up-front (fail fast if the budget is gone).
        if self.quota is not None:
            self.quota.charge(self._cost(resource))

        attempt = 0
        while True:
            route = f"{method} {endpoint}"
            self.limiter.acquire(route)
            status, resp_headers, resp_body = self._transport(
                method, url, headers, body)

            if status == 429:
                retry_after = self._retry_after(resp_headers, resp_body)
                self.limiter.pause(route, retry_after)
                if attempt >= self.max_retries:
                    raise RateLimitedError("rate limited after retries",
                                           retry_after=retry_after)
                self._sleep(retry_after)
                attempt += 1
                continue

            if status >= 500:
                if attempt >= self.max_retries:
                    raise ServerError(f"server error {status}", status=status)
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
            except ValueError:
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
    def _handle(status: int, body: bytes) -> Any:
        try:
            data = json.loads(body) if body else {}
        except json.JSONDecodeError:
            data = {"raw": body.decode(errors="replace")}
        if status == 204 or not body:
            return {}
        if status == 404:
            raise NotFoundError("resource not found", status=404, payload=data)
        if status == 403:
            reason = ""
            if isinstance(data, dict):
                err = data.get("error", {})
                if isinstance(err, dict):
                    errors = err.get("errors", [])
                    if errors and isinstance(errors[0], dict):
                        reason = errors[0].get("reason", "")
            if reason in ("quotaExceeded", "dailyLimitExceeded",
                          "rateLimitExceeded"):
                raise QuotaExceededError(payload=data)
            raise ForbiddenError("forbidden", status=403, payload=data)
        if status >= 400:
            msg = (data.get("error", {}).get("message")
                   if isinstance(data, dict) and isinstance(data.get("error"), dict)
                   else f"HTTP {status}")
            raise YouTubeAPIError(msg or f"HTTP {status}",
                                  status=status, payload=data)
        return data