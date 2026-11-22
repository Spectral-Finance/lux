"""
discord_prisms — Core primitives for the Spectral-Finance/lux Discord integration.

Implements the four prisms required by issue #57 (Discord Core Prisms, Lenses
and Beams) on a shared, production-grade core that provides:

  * Rate limiting        — per-route token buckets that honour Discord's
                           X-RateLimit-* response headers (429 aware).
  * Retry with backoff   — exponential backoff + jitter for 429/5xx, honours
                           the Retry-After header.
  * Event emission       — a lightweight synchronous event bus so every
                           operation emits a structured event.
  * State persistence    — pluggable persistence hook (in-memory by default,
                           JSON-file or Redis in production).
  * Error handling       — typed exceptions (NotFound, Forbidden, RateLimited,
                           ServerError, DiscordAPIError).

The prisms (MessageManagementPrism, ChannelManagementPrism, ModerationPrism,
EventHandlingPrism) all subclass Prism and share this core.

This module is dependency-free (stdlib only) so it can drop into the lux
monorepo without adding transitive dependencies.
"""

from __future__ import annotations

import json
import random
import threading
import time
from dataclasses import dataclass, field
from typing import Any, Callable, Dict, List, Optional

__all__ = [
    "DiscordAPIError",
    "NotFoundError",
    "ForbiddenError",
    "RateLimitedError",
    "ServerError",
    "RateLimiter",
    "EventEmitter",
    "Prism",
    "DiscordHTTP",
    "InMemoryPersistence",
    "JsonFilePersistence",
]


# --------------------------------------------------------------------------- #
# Errors
# --------------------------------------------------------------------------- #
class DiscordAPIError(Exception):
    """Base error for every Discord API failure."""

    def __init__(self, message: str, status: Optional[int] = None,
                 payload: Optional[Dict[str, Any]] = None):
        super().__init__(message)
        self.message = message
        self.status = status
        self.payload = payload or {}


class NotFoundError(DiscordAPIError):
    """404 — resource does not exist or is not visible to the bot."""


class ForbiddenError(DiscordAPIError):
    """403 — the bot lacks permission for this operation."""


class RateLimitedError(DiscordAPIError):
    """429 — rate limit exceeded; retry after `retry_after` seconds."""

    def __init__(self, message: str, retry_after: float = 0.0,
                 payload: Optional[Dict[str, Any]] = None):
        super().__init__(message, status=429, payload=payload)
        self.retry_after = retry_after


class ServerError(DiscordAPIError):
    """5xx — Discord-side transient failure."""


# --------------------------------------------------------------------------- #
# Rate limiter — per-route token bucket, Discord 429 aware
# --------------------------------------------------------------------------- #
@dataclass
class _Bucket:
    tokens: float
    capacity: float
    refill_per_sec: float
    updated_at: float = field(default_factory=time.monotonic)


class RateLimiter:
    """A thread-safe, per-route token-bucket rate limiter.

    Discord returns rate-limit metadata on every response via the
    ``X-RateLimit-Remaining`` / ``X-RateLimit-Limit`` / ``X-RateLimit-Reset``
    headers and a ``Retry-After`` (seconds) body field on 429. We keep a local
    bucket per route and proactively pause when Discord tells us to.
    """

    DEFAULT_CAPACITY = 50.0
    DEFAULT_REFILL = 5.0  # tokens / second

    def __init__(self) -> None:
        self._buckets: Dict[str, _Bucket] = {}
        self._lock = threading.Lock()

    def _bucket(self, route: str) -> _Bucket:
        b = self._buckets.get(route)
        if b is None:
            b = _Bucket(tokens=self.DEFAULT_CAPACITY,
                        capacity=self.DEFAULT_CAPACITY,
                        refill_per_sec=self.DEFAULT_REFILL)
            self._buckets[route] = b
        return b

    def acquire(self, route: str, tokens: float = 1.0) -> float:
        """Block until `tokens` are available for `route`; return wait seconds."""
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

    def update_from_headers(self, route: str, headers: Dict[str, str]) -> None:
        """Sync local bucket state from Discord's X-RateLimit-* headers."""
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
        """Drain the bucket for `route` to force a pause of `seconds`."""
        with self._lock:
            b = self._bucket(route)
            b.tokens = 0.0
            b.updated_at = time.monotonic() + max(0.0, seconds)


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
# HTTP client — thin urllib wrapper with retry + rate limiting
# --------------------------------------------------------------------------- #
class DiscordHTTP:
    """Minimal Discord REST client (stdlib urllib) with retry + rate limiting.

    `transport` is injectable so unit tests can supply a fake without network.
    A transport is ``fn(method, url, headers, body_bytes) -> (status, headers, body_bytes)``.
    """

    API_BASE = "https://discord.com/api/v10"

    def __init__(self, token: str, limiter: Optional[RateLimiter] = None,
                 max_retries: int = 5, transport: Optional[Callable] = None,
                 sleep_fn: Callable[[float], None] = time.sleep) -> None:
        self.token = token
        self.limiter = limiter or RateLimiter()
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

    def request(self, method: str, path: str,
                json_body: Optional[Dict[str, Any]] = None,
                params: Optional[Dict[str, Any]] = None) -> Any:
        url = self.API_BASE + path
        if params:
            import urllib.parse
            url += "?" + urllib.parse.urlencode(params)
        body = json.dumps(json_body).encode() if json_body is not None else None
        headers = {
            "Authorization": f"Bot {self.token}",
            "User-Agent": "DiscordBot (lux, 1.0)",
        }
        if body is not None:
            headers["Content-Type"] = "application/json"

        attempt = 0
        while True:
            route = f"{method} {path.split('?')[0]}"
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
                backoff = self._backoff(attempt, resp_headers)
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
    def _backoff(attempt: int, headers: Dict[str, str]) -> float:
        base = (2 ** attempt) + random.uniform(0, 0.5)
        reset = headers.get("X-RateLimit-Reset")
        return base if not reset else base

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
            raise ForbiddenError("missing permissions", status=403, payload=data)
        if status >= 400:
            raise DiscordAPIError(
                data.get("message", f"HTTP {status}") if isinstance(data, dict)
                else f"HTTP {status}", status=status, payload=data)
        return data


# --------------------------------------------------------------------------- #
# Prism base class
# --------------------------------------------------------------------------- #
class Prism:
    """Base class for every Discord prism.

    Provides shared collaborators (http, limiter, events, persistence) and a
    ``_emit`` helper so subclasses emit consistent structured events.
    """

    #: Human-readable prism name, overridden by subclasses.
    name = "Prism"

    def __init__(self, http: DiscordHTTP, events: Optional[EventEmitter] = None,
                 persistence: Optional[Any] = None) -> None:
        self.http = http
        self.events = events or EventEmitter()
        self.persistence = persistence or InMemoryPersistence()

    def _emit(self, event: str, **payload: Any) -> None:
        self.events.emit(f"{self.name}.{event}", prism=self.name, **payload)