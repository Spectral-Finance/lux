"""
telegram_prisms — Core primitives for the Spectral-Finance/lux Telegram integration.

Implements the shared, production-grade core required by issue #62 (Telegram
Core API Integration) on top of the Telegram Bot API:

  * Rate limiting        — per-method token buckets that honour Telegram's
                            ``parameters.retry_after`` / ``retry_after`` 429
                            metadata (Telegram returns 429 with a JSON body
                            ``{"ok": false, "parameters": {"retry_after": N}}``).
  * Retry with backoff   — exponential backoff + jitter for 429/5xx, honours
                            the ``retry_after`` field returned by Telegram.
  * Event emission       — a lightweight synchronous event bus so every
                            operation emits a structured event.
  * State persistence    — pluggable persistence hook (in-memory by default,
                            JSON-file or Redis in production).
  * Error handling       — typed exceptions (NotFound, Forbidden, RateLimited,
                            ServerError, TelegramAPIError).
  * Secure token mgmt    — :class:`TokenManager` keeps the bot token out of
                            logs/reprs and supports rotation from env / file.

The prisms (BotPrism, MessagePrism, MediaPrism, KeyboardPrism, WebhookPrism,
UpdatePrism) all subclass :class:`Prism` and share this core.

This module is dependency-free (stdlib only) so it can drop into the lux
monorepo without adding transitive dependencies.
"""

from __future__ import annotations

import json
import os
import random
import secrets
import threading
import time
from dataclasses import dataclass, field
from typing import Any, Callable, Dict, List, Optional

__all__ = [
    "TelegramAPIError",
    "NotFoundError",
    "ForbiddenError",
    "RateLimitedError",
    "ServerError",
    "TokenManager",
    "RateLimiter",
    "EventEmitter",
    "Prism",
    "TelegramHTTP",
    "InMemoryPersistence",
    "JsonFilePersistence",
]


# --------------------------------------------------------------------------- #
# Errors
# --------------------------------------------------------------------------- #
class TelegramAPIError(Exception):
    """Base error for every Telegram Bot API failure.

    Telegram wraps every error in a JSON envelope::

        {"ok": false, "error_code": 400, "description": "Bad Request: ..."}

    ``error_code`` mirrors the HTTP status and ``description`` is the human
    readable message. ``parameters`` may carry ``retry_after`` on 429.
    """

    def __init__(self, message: str, status: Optional[int] = None,
                 payload: Optional[Dict[str, Any]] = None):
        super().__init__(message)
        self.message = message
        self.status = status
        self.payload = payload or {}

    @property
    def description(self) -> str:
        return self.message


class NotFoundError(TelegramAPIError):
    """404 — resource does not exist or is not visible to the bot."""


class ForbiddenError(TelegramAPIError):
    """403 — the bot was blocked by the user or lacks permission."""


class RateLimitedError(TelegramAPIError):
    """429 — rate limit exceeded; retry after ``retry_after`` seconds."""

    def __init__(self, message: str, retry_after: float = 0.0,
                 payload: Optional[Dict[str, Any]] = None):
        super().__init__(message, status=429, payload=payload)
        self.retry_after = retry_after


class ServerError(TelegramAPIError):
    """5xx — Telegram-side transient failure."""


# --------------------------------------------------------------------------- #
# Secure token management
# --------------------------------------------------------------------------- #
class TokenManager:
    """Secure holder for a Telegram bot token.

    The token is never included in ``repr``/``str`` output (it is masked) so it
    cannot leak into logs. Tokens can be supplied directly, read from an
    environment variable, or loaded from a file, and rotated at runtime.

    Resolution order for :meth:`resolve`:

    1. explicit ``token`` argument (highest priority),
    2. ``env_var`` (default ``TELEGRAM_BOT_TOKEN``) in ``os.environ``,
    3. ``token_file`` contents (stripped).
    """

    ENV_VAR = "TELEGRAM_BOT_TOKEN"

    def __init__(self, token: Optional[str] = None, *,
                 env_var: Optional[str] = None,
                 token_file: Optional[str] = None) -> None:
        self._lock = threading.Lock()
        self._token: Optional[str] = None
        self._env_var = env_var or self.ENV_VAR
        self._token_file = token_file
        if token is not None:
            self.set(token)
        else:
            self._resolve_from_sources()

    # -- resolution -------------------------------------------------------- #
    def _resolve_from_sources(self) -> None:
        env_val = os.environ.get(self._env_var)
        if env_val:
            self._token = env_val.strip()
            return
        if self._token_file:
            try:
                with open(self._token_file, "r", encoding="utf-8") as fh:
                    self._token = fh.read().strip() or None
            except OSError:
                self._token = None

    def resolve(self, token: Optional[str] = None) -> str:
        """Return a usable token, preferring the explicit argument."""
        if token:
            return token.strip()
        with self._lock:
            if not self._token:
                self._resolve_from_sources()
            if not self._token:
                raise TelegramAPIError(
                    "no Telegram bot token configured "
                    f"(set {self._env_var} or pass token=...)")
            return self._token

    # -- lifecycle --------------------------------------------------------- #
    def set(self, token: str) -> None:
        with self._lock:
            self._token = token.strip()

    def rotate(self, token: str) -> None:
        """Replace the current token (e.g. after a leak or revocation)."""
        self.set(token)

    def is_set(self) -> bool:
        with self._lock:
            return bool(self._token)

    def masked(self) -> str:
        """Return a masked token safe for logging (e.g. ``12345:ab***yz``)."""
        with self._lock:
            tok = self._token or ""
        if not tok:
            return "<unset>"
        if len(tok) <= 8:
            return "***"
        return f"{tok[:6]}***{tok[-2:]}"

    def __repr__(self) -> str:  # never leak the token
        return f"TokenManager(masked={self.masked()!r})"

    __str__ = __repr__


# --------------------------------------------------------------------------- #
# Rate limiter — per-method token bucket, Telegram 429 aware
# --------------------------------------------------------------------------- #
@dataclass
class _Bucket:
    tokens: float
    capacity: float
    refill_per_sec: float
    updated_at: float = field(default_factory=time.monotonic)


class RateLimiter:
    """A thread-safe, per-method token-bucket rate limiter.

    Telegram enforces roughly 30 messages/second globally and per-chat limits of
    ~1 message/second (bursts allowed). On 429 it returns
    ``{"parameters": {"retry_after": N}}``. We keep a local bucket per method
    and proactively pause when Telegram tells us to.
    """

    DEFAULT_CAPACITY = 30.0
    DEFAULT_REFILL = 30.0  # tokens / second

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
        """Sync local bucket state from Telegram's rate-limit headers (if any).

        Telegram does not send X-RateLimit-* headers, but some proxies do; we
        honour them when present and otherwise leave the default bucket alone.
        """
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
class TelegramHTTP:
    """Minimal Telegram Bot API client (stdlib urllib) with retry + rate limiting.

    The Telegram Bot API is a single endpoint (``/bot<token>/<method>``) that
    accepts JSON (or multipart) POST bodies and returns a JSON envelope
    ``{"ok": true, "result": ...}`` or ``{"ok": false, ...}``.

    ``transport`` is injectable so unit tests can supply a fake without network.
    A transport is ``fn(method, url, headers, body_bytes) -> (status, headers,
    body_bytes)``.
    """

    API_BASE = "https://api.telegram.org"

    def __init__(self, token: Any, limiter: Optional[RateLimiter] = None,
                 max_retries: int = 5, transport: Optional[Callable] = None,
                 sleep_fn: Callable[[float], None] = time.sleep,
                 token_manager: Optional[TokenManager] = None) -> None:
        # ``token`` may be a raw string or a TokenManager.
        if isinstance(token, TokenManager):
            self.tokens = token
        else:
            self.tokens = token_manager or TokenManager(token)
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

    def _url_for(self, method: str, token: str) -> str:
        return f"{self.API_BASE}/bot{token}/{method}"

    def request(self, method: str,
                json_body: Optional[Dict[str, Any]] = None,
                params: Optional[Dict[str, Any]] = None,
                files: Optional[Dict[str, bytes]] = None) -> Any:
        """Call a Bot API method and return the ``result`` field.

        ``files`` maps field-name -> raw bytes for multipart uploads (photos,
        documents, voice). When ``files`` is provided the body is encoded as
        ``multipart/form-data`` and any ``json_body`` fields are merged in.
        """
        token = self.tokens.resolve()
        url = self._url_for(method, token)
        route = f"POST {method}"

        if files is not None:
            body, headers = self._encode_multipart(json_body or {}, files)
        else:
            body = json.dumps(json_body or {}).encode()
            headers = {"Content-Type": "application/json"}

        attempt = 0
        while True:
            self.limiter.acquire(route)
            status, resp_headers, resp_body = self._transport(
                "POST", url, headers, body)
            self.limiter.update_from_headers(route, resp_headers)

            # Telegram signals rate limiting with HTTP 429 + retry_after.
            if status == 429:
                retry_after = self._retry_after(resp_body)
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
    def _encode_multipart(fields: Dict[str, Any],
                          files: Dict[str, bytes]):
        """Encode fields + files as multipart/form-data. Returns (body, headers)."""
        boundary = "----luxboundary" + secrets.token_hex(8)
        crlf = b"\r\n"
        out = bytearray()
        for name, value in fields.items():
            if value is None:
                continue
            out += b"--" + boundary.encode() + crlf
            disp = f'Content-Disposition: form-data; name="{name}"'.encode()
            out += disp + crlf + crlf
            out += str(value).encode() + crlf
        for name, content in files.items():
            out += b"--" + boundary.encode() + crlf
            disp = (
                f'Content-Disposition: form-data; name="{name}"; '
                f'filename="{name}"').encode()
            out += disp + crlf
            out += b"Content-Type: application/octet-stream" + crlf + crlf
            out += content + crlf
        out += b"--" + boundary.encode() + b"--" + crlf
        headers = {"Content-Type": f"multipart/form-data; boundary={boundary}"}
        return bytes(out), headers

    @staticmethod
    def _retry_after(body: bytes) -> float:
        """Extract ``parameters.retry_after`` (or top-level) from a 429 body."""
        try:
            data = json.loads(body or b"{}")
        except (json.JSONDecodeError, ValueError, TypeError):
            return 1.0
        if not isinstance(data, dict):
            return 1.0
        params = data.get("parameters") or {}
        if isinstance(params, dict) and "retry_after" in params:
            try:
                return float(params["retry_after"])
            except (TypeError, ValueError):
                pass
        try:
            return float(data.get("retry_after", 1.0))
        except (TypeError, ValueError):
            return 1.0

    @staticmethod
    def _backoff(attempt: int) -> float:
        return (2 ** attempt) + random.uniform(0, 0.5)

    @staticmethod
    def _handle(status: int, body: bytes) -> Any:
        try:
            data = json.loads(body) if body else {}
        except json.JSONDecodeError:
            data = {"ok": False, "description": body.decode(errors="replace")}
        if not isinstance(data, dict):
            return data
        # Telegram always returns an envelope with an "ok" boolean.
        if data.get("ok"):
            return data.get("result")
        # Not ok — map error_code to typed exceptions.
        error_code = data.get("error_code", status)
        description = data.get("description", f"HTTP {status}")
        if error_code == 404 or status == 404:
            raise NotFoundError(description, status=error_code, payload=data)
        if error_code == 403 or status == 403:
            raise ForbiddenError(description, status=error_code, payload=data)
        if error_code == 429 or status == 429:
            raise RateLimitedError(description,
                                   retry_after=TelegramHTTP._retry_after(body),
                                   payload=data)
        if error_code >= 500 or status >= 500:
            raise ServerError(description, status=error_code, payload=data)
        raise TelegramAPIError(description, status=error_code, payload=data)


# --------------------------------------------------------------------------- #
# Prism base class
# --------------------------------------------------------------------------- #
class Prism:
    """Base class for every Telegram prism.

    Provides shared collaborators (http, limiter, events, persistence) and a
    ``_emit`` helper so subclasses emit consistent structured events.
    """

    #: Human-readable prism name, overridden by subclasses.
    name = "Prism"

    def __init__(self, http: TelegramHTTP, events: Optional[EventEmitter] = None,
                 persistence: Optional[Any] = None) -> None:
        self.http = http
        self.events = events or EventEmitter()
        self.persistence = persistence or InMemoryPersistence()

    def _emit(self, event: str, **payload: Any) -> None:
        self.events.emit(f"{self.name}.{event}", prism=self.name, **payload)