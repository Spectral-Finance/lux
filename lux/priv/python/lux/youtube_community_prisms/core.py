"""
youtube_community_prisms.core — shared primitives for the lux YouTube
community-management prisms (issue #70).

This module provides the production-grade substrate every prism builds on:

  * Rate limiting        — per-route token buckets that honour YouTube's
                           ``X-RateLimit-*`` style quota headers and 429s.
  * Retry with backoff   — exponential backoff + jitter for 429/5xx, honours
                           the ``Retry-After`` header.
  * Event emission       — a lightweight synchronous event bus so every
                           operation emits a structured event.
  * State persistence    — pluggable persistence hook (in-memory by default,
                           JSON-file for durable state).
  * Error handling       — typed exceptions (YouTubeAPIError and subclasses).

The module is dependency-free (Python standard library only) so it drops into
the lux monorepo (``lux/priv/python/lux/``) without adding transitive
dependencies, and mirrors the Elixir ``use Lux.Prism`` handler contract
(``handler(input, ctx) -> {:ok, _} | {:error, _}``) via :meth:`Prism.handler`.
"""

from __future__ import annotations

import json
import random
import threading
import time
from dataclasses import dataclass, field
from typing import Any, Callable, Dict, List, Optional, Tuple

__all__ = [
    # errors
    "YouTubeAPIError",
    "NotFoundError",
    "ForbiddenError",
    "RateLimitedError",
    "ServerError",
    "ValidationError",
    "AuthenticationError",
    # infrastructure
    "RateLimiter",
    "EventEmitter",
    "Prism",
    "YouTubeHTTP",
    "InMemoryPersistence",
    "JsonFilePersistence",
]


# --------------------------------------------------------------------------- #
# Errors — typed hierarchy
# --------------------------------------------------------------------------- #
class YouTubeAPIError(Exception):
    """Base error for every YouTube API failure.

    Mirrors the Elixir ``{:error, reason}`` contract: carries a machine
    readable ``code`` plus the raw ``payload`` returned by the API.
    """

    #: Default machine-readable code, overridden by subclasses.
    code = "youtube_api_error"

    def __init__(self, message: str, status: Optional[int] = None,
                 payload: Optional[Dict[str, Any]] = None,
                 code: Optional[str] = None):
        super().__init__(message)
        self.message = message
        self.status = status
        self.payload = payload or {}
        if code is not None:
            self.code = code

    def to_dict(self) -> Dict[str, Any]:
        """Serialise to a JSON-friendly dict (for ``{:error, _}`` returns)."""
        return {
            "error": self.code,
            "message": self.message,
            "status": self.status,
            "payload": self.payload,
        }


class ValidationError(YouTubeAPIError):
    """400 — the request was malformed or failed local validation."""

    code = "validation_error"


class AuthenticationError(YouTubeAPIError):
    """401/403 (auth) — missing or invalid API key / OAuth scope."""

    code = "authentication_error"


class NotFoundError(YouTubeAPIError):
    """404 — resource does not exist or is not visible."""

    code = "not_found"


class ForbiddenError(YouTubeAPIError):
    """403 — the authenticated user lacks permission for this operation."""

    code = "forbidden"


class RateLimitedError(YouTubeAPIError):
    """429 / quotaExceeded — rate limit or daily quota exceeded."""

    code = "rate_limited"

    def __init__(self, message: str, retry_after: float = 0.0,
                 payload: Optional[Dict[str, Any]] = None):
        super().__init__(message, status=429, payload=payload)
        self.retry_after = retry_after


class ServerError(YouTubeAPIError):
    """5xx — YouTube-side transient failure."""

    code = "server_error"


# --------------------------------------------------------------------------- #
# Rate limiter — per-route token bucket, 429 / quota aware
# --------------------------------------------------------------------------- #
@dataclass
class _Bucket:
    tokens: float
    capacity: float
    refill_per_sec: float
    updated_at: float = field(default_factory=time.monotonic)


class RateLimiter:
    """A thread-safe, per-route token-bucket rate limiter.

    YouTube enforces both per-method quotas and a global daily quota (10,000
    units by default). Each route gets its own bucket; the limiter also keeps a
    global ``quota`` counter (in API cost units) so expensive calls such as
    ``search.list`` (100 units) can be throttled against the daily budget.

    ``sleep_fn`` is injectable so tests never actually block.
    """

    DEFAULT_CAPACITY = 50.0
    DEFAULT_REFILL = 5.0  # tokens / second

    def __init__(self, daily_quota: Optional[int] = 10000,
                 sleep_fn: Callable[[float], None] = time.sleep) -> None:
        self._buckets: Dict[str, _Bucket] = {}
        self._lock = threading.Lock()
        self._sleep = sleep_fn
        self.daily_quota = daily_quota
        self.quota_used = 0

    def _bucket(self, route: str) -> _Bucket:
        b = self._buckets.get(route)
        if b is None:
            b = _Bucket(tokens=self.DEFAULT_CAPACITY,
                        capacity=self.DEFAULT_CAPACITY,
                        refill_per_sec=self.DEFAULT_REFILL)
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
            self._sleep(wait)
            waited += wait

    def update_from_headers(self, route: str, headers: Dict[str, str]) -> None:
        """Sync local bucket state from YouTube-style rate-limit headers."""
        try:
            limit = float(headers.get("X-RateLimit-Limit", 0) or 0)
            remaining = float(headers.get("X-RateLimit-Remaining", 0) or 0)
        except (TypeError, ValueError):
            return
        if limit <= 0:
            return
        with self._lock:
            b = self._bucket(route)
            b.capacity = limit
            b.tokens = max(0.0, min(limit, remaining))
            b.refill_per_sec = max(1.0, limit / 60.0)
            b.updated_at = time.monotonic()

    def pause(self, route: str, seconds: float) -> None:
        """Drain the bucket for ``route`` to force a pause of ``seconds``."""
        with self._lock:
            b = self._bucket(route)
            b.tokens = 0.0
            b.updated_at = time.monotonic() + max(0.0, seconds)

    # -- daily quota accounting -------------------------------------------- #
    def charge_quota(self, cost: int) -> None:
        """Record ``cost`` API units against the daily quota."""
        with self._lock:
            self.quota_used += int(cost)

    def quota_remaining(self) -> int:
        with self._lock:
            if self.daily_quota is None:
                return 2 ** 31 - 1
            return max(0, self.daily_quota - self.quota_used)

    def check_quota(self, cost: int) -> None:
        """Raise :class:`RateLimitedError` if ``cost`` would exceed the budget."""
        with self._lock:
            if self.daily_quota is not None and self.quota_used + cost > self.daily_quota:
                raise RateLimitedError(
                    "daily quota exceeded",
                    retry_after=0.0,
                    payload={"quota_used": self.quota_used,
                             "daily_quota": self.daily_quota, "cost": cost},
                )


# --------------------------------------------------------------------------- #
# Event emitter — lightweight synchronous pub/sub
# --------------------------------------------------------------------------- #
class EventEmitter:
    """Minimal synchronous event bus.

    Listeners are called in registration order; a failing listener is isolated
    so it cannot break the emitter. Supports wildcard ``"*"`` listeners that
    receive every event.
    """

    def __init__(self) -> None:
        self._listeners: Dict[str, List[Callable[..., None]]] = {}
        self._lock = threading.Lock()
        self.history: List[Tuple[str, Dict[str, Any]]] = []

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
            handlers += list(self._listeners.get("*", []))
            self.history.append((event, dict(kwargs)))
        for h in handlers:
            try:
                h(event=event, **kwargs)
            except TypeError:
                # Listener may not accept ``event=`` kwarg; retry without it.
                try:
                    h(**kwargs)
                except Exception:  # noqa: BLE001 - isolate listener failures
                    pass
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
# HTTP client — thin urllib wrapper with retry + rate limiting
# --------------------------------------------------------------------------- #
class YouTubeHTTP:
    """Minimal YouTube Data API v3 client (stdlib urllib) with retry + limiting.

    ``transport`` is injectable so unit tests can supply a fake without network.
    A transport is
    ``fn(method, url, headers, body_bytes) -> (status, headers, body_bytes)``.

    ``api_key`` may be an API key (appended as ``?key=``) or an OAuth2 bearer
    token (sent as ``Authorization: Bearer``). ``cost`` is the YouTube quota
    cost of the endpoint (e.g. ``search.list`` = 100, most others = 1).
    """

    API_BASE = "https://www.googleapis.com/youtube/v3"

    #: Quota cost per endpoint (YouTube Data API v3).
    QUOTA_COSTS = {
        "search": 100,
        "videos": 1,
        "channels": 1,
        "commentThreads": 1,
        "comments": 1,
    }

    def __init__(self, api_key: Optional[str] = None,
                 limiter: Optional[RateLimiter] = None,
                 max_retries: int = 5,
                 transport: Optional[Callable] = None,
                 sleep_fn: Callable[[float], None] = time.sleep,
                 oauth: bool = False) -> None:
        self.api_key = api_key
        self.oauth = oauth
        self.limiter = limiter or RateLimiter(sleep_fn=sleep_fn)
        self.max_retries = max_retries
        self._transport = transport or self._urllib_transport
        self._sleep = sleep_fn

    # -- transport --------------------------------------------------------- #
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

    # -- public API -------------------------------------------------------- #
    def request(self, method: str, path: str,
                json_body: Optional[Dict[str, Any]] = None,
                params: Optional[Dict[str, Any]] = None,
                cost: Optional[int] = None) -> Any:
        """Execute a request against the YouTube Data API with retry/limiting."""
        endpoint = path.strip("/").split("/")[0]
        if cost is None:
            cost = self.QUOTA_COSTS.get(endpoint, 1)
        self.limiter.check_quota(cost)

        url = self.API_BASE + "/" + path.lstrip("/")
        query: Dict[str, Any] = dict(params or {})
        if self.api_key and not self.oauth:
            query["key"] = self.api_key
        if query:
            import urllib.parse
            url += "?" + urllib.parse.urlencode(
                {k: v for k, v in query.items() if v is not None})

        body = json.dumps(json_body).encode() if json_body is not None else None
        headers = {"User-Agent": "lux-youtube-community/1.0"}
        if self.oauth and self.api_key:
            headers["Authorization"] = f"Bearer {self.api_key}"
        if body is not None:
            headers["Content-Type"] = "application/json"

        attempt = 0
        while True:
            route = f"{method} {endpoint}"
            self.limiter.acquire(route)
            status, resp_headers, resp_body = self._transport(
                method, url, headers, body)
            self.limiter.update_from_headers(route, resp_headers)

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

            data = self._handle(status, resp_body)
            self.limiter.charge_quota(cost)
            return data

    # -- helpers ----------------------------------------------------------- #
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
            err = data.get("error", {}) if isinstance(data, dict) else {}
            for key in ("retryAfter", "retry_after"):
                if isinstance(err, dict) and key in err:
                    return float(err[key])
            if "retry_after" in data:
                return float(data["retry_after"])
        except (json.JSONDecodeError, ValueError, TypeError):
            pass
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
        if status == 401:
            raise AuthenticationError("unauthorized", status=401, payload=data)
        if status == 403:
            # Distinguish quota from permission errors.
            reason = ""
            if isinstance(data, dict):
                err = data.get("error", {})
                if isinstance(err, dict):
                    errs = err.get("errors") or []
                    if errs and isinstance(errs[0], dict):
                        reason = errs[0].get("reason", "")
            if reason in ("quotaExceeded", "dailyLimitExceeded", "rateLimitExceeded"):
                raise RateLimitedError("quota exceeded", payload=data)
            raise ForbiddenError("missing permissions", status=403, payload=data)
        if status == 400:
            raise ValidationError("bad request", status=400, payload=data)
        if status >= 400:
            msg = "HTTP %d" % status
            if isinstance(data, dict):
                err = data.get("error", {})
                if isinstance(err, dict) and err.get("message"):
                    msg = err["message"]
            raise YouTubeAPIError(msg, status=status, payload=data)
        return data


# --------------------------------------------------------------------------- #
# Prism base class
# --------------------------------------------------------------------------- #
class Prism:
    """Base class for every YouTube community prism.

    Provides shared collaborators (``http``, ``limiter``, ``events``,
    ``persistence``), a ``_emit`` helper for structured events, and a
    Lux-compatible ``handler(input, ctx)`` entry point that returns
    ``{"ok": True, "data": ...}`` / ``{"ok": False, "error": ...}`` — the
    Python analogue of Elixir's ``{:ok, _} | {:error, _}``.
    """

    #: Human-readable prism name, overridden by subclasses.
    name = "Prism"

    def __init__(self, http: YouTubeHTTP,
                 events: Optional[EventEmitter] = None,
                 persistence: Optional[Any] = None) -> None:
        self.http = http
        self.limiter = http.limiter
        self.events = events or EventEmitter()
        self.persistence = persistence or InMemoryPersistence()

    def _emit(self, event: str, **payload: Any) -> None:
        self.events.emit(f"{self.name}.{event}", prism=self.name, **payload)

    def handler(self, action: str, params: Optional[Dict[str, Any]] = None,
                ctx: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Lux-compatible dispatch entry point.

        ``action`` names a method on the prism; ``params`` are forwarded as
        keyword arguments. Returns ``{"ok": True, "data": ...}`` on success or
        ``{"ok": False, "error": {...}}`` on failure, mirroring the Elixir
        prism contract.
        """
        params = params or {}
        method = getattr(self, action, None)
        if method is None or action.startswith("_"):
            return {"ok": False,
                    "error": ValidationError(
                        f"unknown action {action!r} for {self.name}").to_dict()}
        try:
            data = method(**params)
            return {"ok": True, "data": data}
        except YouTubeAPIError as exc:
            return {"ok": False, "error": exc.to_dict()}
        except (ValueError, TypeError) as exc:
            return {"ok": False,
                    "error": ValidationError(str(exc)).to_dict()}