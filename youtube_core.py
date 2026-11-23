"""YouTube Core Integration and Live Streaming suite for Lux.

This module provides a production-grade, dependency-free client for the
YouTube Data API v3 together with the YouTube Live Streaming API. It is
designed to be driven by Lux agents (via the Python prism subsystem) but has
no hard dependency on the Lux runtime so it can be unit-tested fully offline.

Design goals
------------
* **Stdlib only.** Uses ``urllib`` for HTTP so the suite runs anywhere the
  Lux Python package runs, with no extra wheels required.
* **Injectable transport.** All network traffic flows through a single
  :class:`Transport` protocol. Tests inject a fake transport, so the entire
  suite runs offline with no live credentials.
* **Typed responses.** Every API call returns a :class:`YouTubeResponse`
  carrying a parsed ``body`` plus ``status``/``headers`` metadata.
* **OAuth2 + token management.** :class:`OAuth2` implements the
  authorization-code, refresh-token and device-code flows and transparently
  refreshes expired access tokens.
* **Resilience.** A :class:`RateLimiter` enforces per-endpoint quotas and a
  retry policy with exponential backoff handles transient failures.
* **Full resource coverage.** Channels, videos, playlists, playlist items,
  search, live streams, live broadcasts, and live chat messages.

The module is intentionally import-light: importing it never touches the
network and never requires credentials.
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Callable, Dict, Iterable, List, Optional, Protocol, Tuple

__all__ = [
    "YouTubeError",
    "YouTubeAPIError",
    "AuthenticationError",
    "RateLimitError",
    "QuotaExceededError",
    "NotFoundError",
    "BadRequestError",
    "ForbiddenError",
    "YouTubeResponse",
    "Transport",
    "UrllibTransport",
    "RateLimiter",
    "RetryPolicy",
    "OAuth2",
    "OAuth2Config",
    "TokenSet",
    "Channel",
    "Video",
    "Playlist",
    "PlaylistItem",
    "LiveStream",
    "LiveBroadcast",
    "LiveChatMessage",
    "StreamHealth",
    "BroadcastTransition",
    "StreamStatus",
    "BroadcastStatus",
    "YouTubeClient",
    "YouTubeCore",
    "PubSubHubbub",
    "WebhookVerification",
    "WebhookNotification",
    "WebhookVerifier",
]

API_BASE = "https://www.googleapis.com/youtube/v3"
LIVE_BASE = "https://www.googleapis.com/youtube/v3"
OAUTH_BASE = "https://oauth2.googleapis.com"
TOKEN_URL = OAUTH_BASE + "/token"
DEVICE_CODE_URL = OAUTH_BASE + "/device/code"
AUTHORIZE_URL = "https://accounts.google.com/o/oauth2/v2/auth"
UPLOAD_BASE = "https://www.googleapis.com/upload/youtube/v3"

# OAuth scopes required for the various capabilities.
SCOPE_READONLY = "https://www.googleapis.com/auth/youtube.readonly"
SCOPE_UPLOAD = "https://www.googleapis.com/auth/youtube.upload"
SCOPE_LIVE = "https://www.googleapis.com/auth/youtube"
SCOPE_CHAT = "https://www.googleapis.com/auth/youtube.force-ssl"
SCOPE_CHANNEL = "https://www.googleapis.com/auth/youtube.channel-memberships.creator"


# ---------------------------------------------------------------------------
# Errors
# ---------------------------------------------------------------------------
class YouTubeError(Exception):
    """Base class for all errors raised by this module."""


class YouTubeAPIError(YouTubeError):
    """Raised when the YouTube API returns a non-success response.

    Attributes
    ----------
    status:
        HTTP status code returned by the API.
    reason:
        Machine-readable error reason (e.g. ``"quotaExceeded"``).
    message:
        Human-readable error message.
    errors:
        The raw list of error detail objects from the API, when present.
    """

    def __init__(
        self,
        status: int,
        reason: str,
        message: str,
        errors: Optional[List[Dict[str, Any]]] = None,
    ) -> None:
        self.status = status
        self.reason = reason
        self.message = message
        self.errors = errors or []
        super().__init__(f"[{status}] {reason}: {message}")

    @property
    def retryable(self) -> bool:
        """Whether the request that produced this error may be retried."""
        return self.status in (500, 502, 503, 504) or self.status == 429


class AuthenticationError(YouTubeAPIError):
    """Raised for 401/403 authentication or authorization failures."""


class ForbiddenError(YouTubeAPIError):
    """Raised for 403 permission failures that are not auth-related."""


class NotFoundError(YouTubeAPIError):
    """Raised for 404 responses."""


class BadRequestError(YouTubeAPIError):
    """Raised for 400 responses (invalid request / parameters)."""


class RateLimitError(YouTubeAPIError):
    """Raised when the client-side rate limiter blocks a request."""


class QuotaExceededError(YouTubeAPIError):
    """Raised when the API reports the daily quota has been exhausted."""


def _error_from_payload(status: int, payload: Dict[str, Any]) -> YouTubeAPIError:
    """Build the most specific :class:`YouTubeAPIError` for a payload."""
    err = (payload or {}).get("error") or {}
    if not isinstance(err, dict):
        err = {"message": str(err)}
    message = err.get("message", "Unknown error")
    errors = err.get("errors") or []
    reason = "unknown"
    if errors and isinstance(errors, list):
        reason = errors[0].get("reason", reason)
    else:
        reason = err.get("status", reason)

    kwargs = dict(status=status, reason=reason, message=message, errors=errors)
    if status == 401:
        return AuthenticationError(**kwargs)
    if status == 403:
        if reason in ("quotaExceeded", "dailyLimitExceeded", "rateLimitExceeded"):
            return QuotaExceededError(**kwargs)
        return ForbiddenError(**kwargs)
    if status == 404:
        return NotFoundError(**kwargs)
    if status == 400:
        return BadRequestError(**kwargs)
    if status == 429:
        return QuotaExceededError(**kwargs)
    return YouTubeAPIError(**kwargs)


# ---------------------------------------------------------------------------
# Response + transport
# ---------------------------------------------------------------------------
@dataclass
class YouTubeResponse:
    """A typed wrapper around a single YouTube API response."""

    status: int
    body: Dict[str, Any]
    headers: Dict[str, str] = field(default_factory=dict)

    @property
    def ok(self) -> bool:
        return 200 <= self.status < 300

    @property
    def etag(self) -> Optional[str]:
        return self.headers.get("ETag") or self.headers.get("etag")

    def items(self, key: str = "items") -> List[Dict[str, Any]]:
        """Return the list stored under ``key`` (defaults to ``items``)."""
        value = self.body.get(key, [])
        return value if isinstance(value, list) else []

    def first(self, key: str = "items") -> Optional[Dict[str, Any]]:
        items = self.items(key)
        return items[0] if items else None


class Transport(Protocol):
    """Protocol for HTTP transports.

    A transport takes a fully-formed :class:`urllib.request.Request` and
    returns a ``(status, headers, body_bytes)`` tuple. Tests provide a fake
    implementation so the suite never touches the network.
    """

    def send(self, request: urllib.request.Request) -> Tuple[int, Dict[str, str], bytes]:
        ...


class UrllibTransport:
    """Default transport backed by :mod:`urllib`."""

    def __init__(self, timeout: float = 30.0) -> None:
        self.timeout = timeout

    def send(self, request: urllib.request.Request) -> Tuple[int, Dict[str, str], bytes]:
        try:
            with urllib.request.urlopen(request, timeout=self.timeout) as resp:  # noqa: S310
                body = resp.read()
                headers = {k: v for k, v in resp.getheaders()}
                return resp.getcode(), headers, body
        except urllib.error.HTTPError as exc:  # non-2xx still carries a body
            body = exc.read() if hasattr(exc, "read") else b""
            headers = dict(exc.headers.items()) if exc.headers else {}
            return exc.code, headers, body


# ---------------------------------------------------------------------------
# Rate limiting + retries
# ---------------------------------------------------------------------------
class RateLimiter:
    """A simple sliding-window rate limiter.

    Parameters
    ----------
    max_calls:
        Maximum number of calls allowed within ``period`` seconds.
    period:
        Length of the sliding window in seconds.
    time_func:
        Injectable clock (defaults to :func:`time.monotonic`) for testing.
    """

    def __init__(
        self,
        max_calls: int = 100,
        period: float = 60.0,
        time_func: Callable[[], float] = time.monotonic,
    ) -> None:
        self.max_calls = max(1, int(max_calls))
        self.period = float(period)
        self._clock = time_func
        self._calls: List[float] = []

    def _prune(self, now: float) -> None:
        cutoff = now - self.period
        self._calls = [t for t in self._calls if t > cutoff]

    def acquire(self, cost: int = 1) -> float:
        """Block until ``cost`` units are available, then record them.

        Returns the number of seconds slept (0 when no wait was required).
        """
        slept = 0.0
        # A zero-cost acquisition is always allowed and never blocks.
        if cost <= 0:
            return slept
        # A single request whose cost exceeds the whole window capacity can
        # never fit; clamp it so we still make progress rather than looping
        # forever (or indexing an empty call list).
        cost = min(int(cost), self.max_calls)
        while True:
            now = self._clock()
            self._prune(now)
            if len(self._calls) + cost <= self.max_calls:
                self._calls.extend([now] * cost)
                return slept
            oldest = self._calls[0]
            wait = (oldest + self.period) - now
            if wait <= 0:
                continue
            time.sleep(wait)
            slept += wait

    def try_acquire(self, cost: int = 1) -> bool:
        """Non-blocking variant. Returns ``True`` if the cost was recorded."""
        now = self._clock()
        self._prune(now)
        if len(self._calls) + cost <= self.max_calls:
            self._calls.extend([now] * cost)
            return True
        return False

    def remaining(self) -> int:
        self._prune(self._clock())
        return max(0, self.max_calls - len(self._calls))


@dataclass
class RetryPolicy:
    """Configuration for retrying transient failures.

    Parameters
    ----------
    max_retries:
        Maximum number of *retries* after the initial attempt.
    backoff:
        Base delay in seconds for exponential backoff.
    multiplier:
        Backoff multiplier applied per attempt.
    max_backoff:
        Upper bound on any single backoff sleep.
    jitter:
        Fraction of random jitter (0.0-1.0) added to each backoff.
    retry_statuses:
        HTTP status codes considered retryable.
    sleep_func:
        Injectable sleep function (defaults to :func:`time.sleep`).
    """

    max_retries: int = 3
    backoff: float = 0.5
    multiplier: float = 2.0
    max_backoff: float = 30.0
    jitter: float = 0.1
    retry_statuses: Tuple[int, ...] = (429, 500, 502, 503, 504)
    sleep_func: Callable[[float], None] = time.sleep

    def compute_backoff(self, attempt: int) -> float:
        """Return the backoff delay (seconds) for a zero-based ``attempt``."""
        delay = self.backoff * (self.multiplier ** attempt)
        delay = min(delay, self.max_backoff)
        if self.jitter:
            delay += delay * self.jitter * ((attempt % 3) - 1) * 0.5
        return max(0.0, delay)

    def should_retry(self, status: int, attempt: int) -> bool:
        return status in self.retry_statuses and attempt < self.max_retries


def _resource_from_response(resp: "YouTubeResponse") -> Dict[str, Any]:
    """Extract a single resource dict from a response body.

    Create/update endpoints return the resource object directly, while some
    responses wrap it in an ``items`` list. This normalizes both shapes.
    """
    body = resp.body or {}
    if "items" in body and isinstance(body["items"], list) and body["items"]:
        return body["items"][0]
    return body


# ---------------------------------------------------------------------------
# OAuth2 + token management
# ---------------------------------------------------------------------------
@dataclass
class OAuth2Config:
    """Configuration for the OAuth2 client.

    Parameters
    ----------
    client_id / client_secret:
        OAuth application credentials.
    token_url / device_code_url / authorize_url:
        Endpoint overrides (useful for testing).
    redirect_uri:
        Redirect URI registered with the OAuth application.
    scopes:
        Tuple of OAuth scopes to request.
    """

    client_id: str
    client_secret: str = ""
    token_url: str = TOKEN_URL
    device_code_url: str = DEVICE_CODE_URL
    authorize_url: str = AUTHORIZE_URL
    redirect_uri: str = "urn:ietf:wg:oauth:2.0:oob"
    scopes: Tuple[str, ...] = (SCOPE_READONLY,)


@dataclass
class TokenSet:
    """An OAuth2 token set with expiry tracking."""

    access_token: str
    refresh_token: Optional[str] = None
    token_type: str = "Bearer"
    expires_in: int = 3600
    issued_at: float = field(default_factory=time.time)
    scope: str = ""

    @property
    def expires_at(self) -> float:
        return self.issued_at + self.expires_in

    def is_expired(self, leeway: float = 60.0, now: Optional[float] = None) -> bool:
        """Return ``True`` if the token is expired (with a safety ``leeway``)."""
        current = now if now is not None else time.time()
        return current >= (self.expires_at - leeway)

    @classmethod
    def from_payload(cls, payload: Dict[str, Any]) -> "TokenSet":
        return cls(
            access_token=payload["access_token"],
            refresh_token=payload.get("refresh_token"),
            token_type=payload.get("token_type", "Bearer"),
            expires_in=int(payload.get("expires_in", 3600)),
            scope=payload.get("scope", ""),
        )

    def to_dict(self) -> Dict[str, Any]:
        return {
            "access_token": self.access_token,
            "refresh_token": self.refresh_token,
            "token_type": self.token_type,
            "expires_in": self.expires_in,
            "scope": self.scope,
        }


class OAuth2:
    """OAuth2 helper supporting auth-code, refresh and device-code flows."""

    def __init__(
        self,
        config: OAuth2Config,
        transport: Optional[Transport] = None,
        token_store: Optional[Dict[str, Any]] = None,
    ) -> None:
        self.config = config
        self.transport = transport or UrllibTransport()
        self._token: Optional[TokenSet] = None
        self._store = token_store if token_store is not None else {}
        if self._store.get("access_token"):
            self._token = TokenSet(
                access_token=self._store["access_token"],
                refresh_token=self._store.get("refresh_token"),
                expires_in=int(self._store.get("expires_in", 3600)),
                issued_at=float(self._store.get("issued_at", time.time())),
                scope=self._store.get("scope", ""),
            )

    # -- token lifecycle -------------------------------------------------
    @property
    def token(self) -> Optional[TokenSet]:
        return self._token

    def set_token(self, token: TokenSet) -> None:
        self._token = token
        self._persist()

    def _persist(self) -> None:
        if self._token is not None:
            self._store.update(self._token.to_dict())
            self._store["issued_at"] = self._token.issued_at

    def authorization_url(
        self,
        state: Optional[str] = None,
        access_type: str = "offline",
        prompt: str = "consent",
    ) -> str:
        """Build the user-facing authorization URL for the auth-code flow."""
        params = {
            "client_id": self.config.client_id,
            "redirect_uri": self.config.redirect_uri,
            "response_type": "code",
            "scope": " ".join(self.config.scopes),
            "access_type": access_type,
            "prompt": prompt,
        }
        if state:
            params["state"] = state
        return self.config.authorize_url + "?" + urllib.parse.urlencode(params)

    def exchange_code(self, code: str) -> TokenSet:
        """Exchange an authorization ``code`` for a :class:`TokenSet`."""
        payload = self._token_request(
            {
                "code": code,
                "client_id": self.config.client_id,
                "client_secret": self.config.client_secret,
                "redirect_uri": self.config.redirect_uri,
                "grant_type": "authorization_code",
            }
        )
        self.set_token(TokenSet.from_payload(payload))
        return self._token  # type: ignore[return-value]

    def refresh(self, refresh_token: Optional[str] = None) -> TokenSet:
        """Refresh the access token using a refresh token."""
        token = refresh_token or (self._token.refresh_token if self._token else None)
        if not token:
            raise AuthenticationError(
                401, "noRefreshToken", "No refresh token available to refresh access token"
            )
        payload = self._token_request(
            {
                "refresh_token": token,
                "client_id": self.config.client_id,
                "client_secret": self.config.client_secret,
                "grant_type": "refresh_token",
            }
        )
        payload.setdefault("refresh_token", token)
        self.set_token(TokenSet.from_payload(payload))
        return self._token  # type: ignore[return-value]

    def request_device_code(self) -> Dict[str, Any]:
        """Initiate the device-code flow and return the device authorization."""
        body = urllib.parse.urlencode(
            {"client_id": self.config.client_id, "scope": " ".join(self.config.scopes)}
        ).encode("utf-8")
        request = urllib.request.Request(
            self.config.device_code_url,
            data=body,
            headers={"Content-Type": "application/x-www-form-urlencoded"},
            method="POST",
        )
        status, _, raw = self.transport.send(request)
        payload = json.loads(raw.decode("utf-8") or "{}")
        if status >= 400:
            raise _error_from_payload(status, payload)
        return payload

    def poll_device_token(self, device_code: str, interval: int = 5) -> TokenSet:
        """Poll the token endpoint until the device-code flow completes."""
        while True:
            payload = self._token_request(
                {
                    "device_code": device_code,
                    "client_id": self.config.client_id,
                    "client_secret": self.config.client_secret,
                    "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
                },
                raise_on_error=False,
            )
            if "access_token" in payload:
                self.set_token(TokenSet.from_payload(payload))
                return self._token  # type: ignore[return-value]
            error = payload.get("error")
            if error == "authorization_pending":
                time.sleep(interval)
                continue
            if error == "slow_down":
                interval += 5
                time.sleep(interval)
                continue
            raise AuthenticationError(
                400, error or "deviceAuthError", payload.get("error_description", "device auth failed")
            )

    def get_access_token(self, leeway: float = 60.0) -> str:
        """Return a valid access token, refreshing transparently if needed."""
        if self._token is None:
            raise AuthenticationError(
                401, "noToken", "No OAuth token configured; authenticate first"
            )
        if self._token.is_expired(leeway=leeway):
            self.refresh()
        return self._token.access_token  # type: ignore[union-attr]

    # -- internals -------------------------------------------------------
    def _token_request(
        self, form: Dict[str, Any], raise_on_error: bool = True
    ) -> Dict[str, Any]:
        body = urllib.parse.urlencode(form).encode("utf-8")
        request = urllib.request.Request(
            self.config.token_url,
            data=body,
            headers={"Content-Type": "application/x-www-form-urlencoded"},
            method="POST",
        )
        status, _, raw = self.transport.send(request)
        payload = json.loads(raw.decode("utf-8") or "{}")
        if status >= 400 and raise_on_error:
            raise _error_from_payload(status, payload)
        return payload


# ---------------------------------------------------------------------------
# Typed resource models
# ---------------------------------------------------------------------------
@dataclass
class Channel:
    id: str
    title: str = ""
    description: str = ""
    custom_url: str = ""
    published_at: str = ""
    thumbnails: Dict[str, Any] = field(default_factory=dict)
    subscriber_count: Optional[int] = None
    video_count: Optional[int] = None
    view_count: Optional[int] = None
    uploads_playlist_id: Optional[str] = None
    raw: Dict[str, Any] = field(default_factory=dict)

    @classmethod
    def from_api(cls, data: Dict[str, Any]) -> "Channel":
        snippet = data.get("snippet", {})
        stats = data.get("statistics", {})
        content = data.get("contentDetails", {})
        return cls(
            id=data.get("id", ""),
            title=snippet.get("title", ""),
            description=snippet.get("description", ""),
            custom_url=snippet.get("customUrl", ""),
            published_at=snippet.get("publishedAt", ""),
            thumbnails=snippet.get("thumbnails", {}),
            subscriber_count=_to_int(stats.get("subscriberCount")),
            video_count=_to_int(stats.get("videoCount")),
            view_count=_to_int(stats.get("viewCount")),
            uploads_playlist_id=content.get("relatedPlaylists", {}).get("uploads"),
            raw=data,
        )


@dataclass
class Video:
    id: str
    title: str = ""
    description: str = ""
    channel_id: str = ""
    channel_title: str = ""
    published_at: str = ""
    privacy_status: str = "private"
    tags: List[str] = field(default_factory=list)
    duration: str = ""
    view_count: Optional[int] = None
    like_count: Optional[int] = None
    comment_count: Optional[int] = None
    thumbnails: Dict[str, Any] = field(default_factory=dict)
    raw: Dict[str, Any] = field(default_factory=dict)

    @classmethod
    def from_api(cls, data: Dict[str, Any]) -> "Video":
        snippet = data.get("snippet", {})
        stats = data.get("statistics", {})
        status = data.get("status", {})
        content = data.get("contentDetails", {})
        return cls(
            id=data.get("id", ""),
            title=snippet.get("title", ""),
            description=snippet.get("description", ""),
            channel_id=snippet.get("channelId", ""),
            channel_title=snippet.get("channelTitle", ""),
            published_at=snippet.get("publishedAt", ""),
            privacy_status=status.get("privacyStatus", "private"),
            tags=snippet.get("tags", []) or [],
            duration=content.get("duration", ""),
            view_count=_to_int(stats.get("viewCount")),
            like_count=_to_int(stats.get("likeCount")),
            comment_count=_to_int(stats.get("commentCount")),
            thumbnails=snippet.get("thumbnails", {}),
            raw=data,
        )


@dataclass
class Playlist:
    id: str
    title: str = ""
    description: str = ""
    channel_id: str = ""
    privacy_status: str = "private"
    item_count: Optional[int] = None
    published_at: str = ""
    raw: Dict[str, Any] = field(default_factory=dict)

    @classmethod
    def from_api(cls, data: Dict[str, Any]) -> "Playlist":
        snippet = data.get("snippet", {})
        status = data.get("status", {})
        stats = data.get("contentDetails", {})
        return cls(
            id=data.get("id", ""),
            title=snippet.get("title", ""),
            description=snippet.get("description", ""),
            channel_id=snippet.get("channelId", ""),
            privacy_status=status.get("privacyStatus", "private"),
            item_count=_to_int(stats.get("itemCount")),
            published_at=snippet.get("publishedAt", ""),
            raw=data,
        )


@dataclass
class PlaylistItem:
    id: str
    playlist_id: str = ""
    video_id: str = ""
    title: str = ""
    position: int = 0
    published_at: str = ""
    raw: Dict[str, Any] = field(default_factory=dict)

    @classmethod
    def from_api(cls, data: Dict[str, Any]) -> "PlaylistItem":
        snippet = data.get("snippet", {})
        return cls(
            id=data.get("id", ""),
            playlist_id=snippet.get("playlistId", ""),
            video_id=snippet.get("resourceId", {}).get("videoId", ""),
            title=snippet.get("title", ""),
            position=int(snippet.get("position", 0)),
            published_at=snippet.get("publishedAt", ""),
            raw=data,
        )


class StreamStatus(str, Enum):
    """Lifecycle states of a live stream."""

    ACTIVE = "active"
    CREATED = "created"
    ERROR = "error"
    INACTIVE = "inactive"
    READY = "ready"


class BroadcastStatus(str, Enum):
    """Lifecycle states of a live broadcast."""

    ACTIVE = "active"
    ALL = "all"
    COMPLETE = "complete"
    ENDED = "ended"
    UPCOMING = "upcoming"


class BroadcastTransition(str, Enum):
    """Valid broadcast lifecycle transitions."""

    TESTING = "testing"
    LIVE = "live"
    PAUSE = "pause"
    COMPLETE = "complete"
    END = "end"


@dataclass
class StreamHealth:
    """Aggregated health snapshot for a live stream."""

    status: str = "unknown"
    configuration_issue: bool = False
    reason: str = ""
    latency: str = ""
    frame_rate: str = ""
    resolution: str = ""
    bitrate_bps: int = 0
    is_healthy: bool = True
    raw: Dict[str, Any] = field(default_factory=dict)

    @classmethod
    def from_api(cls, data: Dict[str, Any]) -> "StreamHealth":
        status_obj = data.get("status", {})
        # ``streamStatus`` may be a plain string ("active") or a nested dict
        # carrying configurationIssueDetails. Normalize both shapes.
        stream_status = status_obj.get("streamStatus", "unknown")
        if isinstance(stream_status, dict):
            status = stream_status.get("streamStatus", "unknown")
            issues = stream_status.get("configurationIssueDetails") or []
        else:
            status = stream_status
            issues = status_obj.get("configurationIssueDetails") or []
        stats = data.get("statistics", {})
        reason = issues[0] if issues else ""
        return cls(
            status=status,
            configuration_issue=bool(issues),
            reason=reason,
            latency=stats.get("frameRate", ""),
            frame_rate=stats.get("frameRate", ""),
            resolution=stats.get("resolution", ""),
            bitrate_bps=_to_int(stats.get("bitrateBps", 0)),
            is_healthy=status in ("active", "ready") and not issues,
            raw=data,
        )


@dataclass
class LiveStream:
    id: str
    title: str = ""
    stream_key: str = ""
    ingestion_address: str = ""
    backup_ingestion_address: str = ""
    rtmps: Dict[str, str] = field(default_factory=dict)
    status: str = "created"
    health: Optional[StreamHealth] = None
    raw: Dict[str, Any] = field(default_factory=dict)

    @classmethod
    def from_api(cls, data: Dict[str, Any]) -> "LiveStream":
        snippet = data.get("snippet", {})
        cdn = data.get("cdn", {})
        info = cdn.get("ingestionInfo", {})
        status = data.get("status", {}).get("streamStatus", "created")
        health = None
        if isinstance(data.get("status"), dict) and "streamStatus" in data["status"]:
            health = StreamHealth.from_api(data)
        return cls(
            id=data.get("id", ""),
            title=snippet.get("title", ""),
            stream_key=info.get("streamName", ""),
            ingestion_address=info.get("ingestionAddress", ""),
            backup_ingestion_address=info.get("backupIngestionAddress", ""),
            rtmps=info.get("rtmps", {}) if isinstance(info.get("rtmps"), dict) else {},
            status=status,
            health=health,
            raw=data,
        )


@dataclass
class LiveBroadcast:
    id: str
    title: str = ""
    description: str = ""
    status: str = "upcoming"
    privacy_status: str = "private"
    scheduled_start_time: str = ""
    scheduled_end_time: str = ""
    actual_start_time: str = ""
    actual_end_time: str = ""
    live_chat_id: str = ""
    bound_stream_id: str = ""
    thumbnail_url: str = ""
    raw: Dict[str, Any] = field(default_factory=dict)

    @classmethod
    def from_api(cls, data: Dict[str, Any]) -> "LiveBroadcast":
        snippet = data.get("snippet", {})
        status = data.get("status", {})
        content = data.get("contentDetails", {})
        return cls(
            id=data.get("id", ""),
            title=snippet.get("title", ""),
            description=snippet.get("description", ""),
            status=status.get("lifeCycleStatus", "upcoming"),
            privacy_status=status.get("privacyStatus", "private"),
            scheduled_start_time=snippet.get("scheduledStartTime", ""),
            scheduled_end_time=snippet.get("scheduledEndTime", ""),
            actual_start_time=status.get("actualStartTime", ""),
            actual_end_time=status.get("actualEndTime", ""),
            live_chat_id=snippet.get("liveChatId", ""),
            bound_stream_id=content.get("boundStreamId", ""),
            thumbnail_url=snippet.get("thumbnails", {}).get("high", {}).get("url", ""),
            raw=data,
        )


@dataclass
class LiveChatMessage:
    id: str
    text: str = ""
    author: str = ""
    author_channel_id: str = ""
    published_at: str = ""
    is_moderator: bool = False
    is_owner: bool = False
    message_type: str = "textMessageEvent"
    raw: Dict[str, Any] = field(default_factory=dict)

    @classmethod
    def from_api(cls, data: Dict[str, Any]) -> "LiveChatMessage":
        snippet = data.get("snippet", {})
        author = snippet.get("authorDetails", {})
        return cls(
            id=data.get("id", ""),
            text=snippet.get("displayMessage", ""),
            author=author.get("displayName", ""),
            author_channel_id=author.get("channelId", ""),
            published_at=snippet.get("publishedAt", ""),
            is_moderator=bool(author.get("isChatModerator", False)),
            is_owner=bool(author.get("isChatOwner", False)),
            message_type=snippet.get("type", "textMessageEvent"),
            raw=data,
        )


def _to_int(value: Any) -> Optional[int]:
    """Best-effort conversion of an API numeric string to ``int``."""
    if value is None:
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _decode_body(raw: bytes) -> Dict[str, Any]:
    """Decode a response body into a dict, tolerating empty/non-JSON bodies."""
    if not raw:
        return {}
    try:
        return json.loads(raw.decode("utf-8"))
    except (ValueError, UnicodeDecodeError):
        return {"_raw": raw.decode("utf-8", errors="replace")}


# ---------------------------------------------------------------------------
# Core client
# ---------------------------------------------------------------------------
class YouTubeClient:
    """Low-level YouTube Data API v3 + Live Streaming API client.

    Parameters
    ----------
    oauth:
        An authenticated :class:`OAuth2` instance (or any object exposing
        ``get_access_token()``).
    api_key:
        Optional API key for public, read-only requests.
    transport:
        HTTP transport (injectable for offline tests).
    rate_limiter:
        Client-side rate limiter.
    retry_policy:
        Retry/backoff policy for transient failures.
    """

    def __init__(
        self,
        oauth: Optional[OAuth2] = None,
        api_key: Optional[str] = None,
        transport: Optional[Transport] = None,
        rate_limiter: Optional[RateLimiter] = None,
        retry_policy: Optional[RetryPolicy] = None,
        base_url: str = API_BASE,
        upload_url: str = UPLOAD_BASE,
    ) -> None:
        self.oauth = oauth
        self.api_key = api_key
        self.transport = transport or UrllibTransport()
        self.rate_limiter = rate_limiter or RateLimiter()
        self.retry_policy = retry_policy or RetryPolicy()
        self.base_url = base_url
        self.upload_url = upload_url

    # -- request plumbing ------------------------------------------------
    def _auth_headers(self) -> Dict[str, str]:
        headers = {"Accept": "application/json"}
        if self.oauth is not None:
            token = self.oauth.get_access_token()
            headers["Authorization"] = f"Bearer {token}"
        return headers

    def request(
        self,
        method: str,
        path: str,
        params: Optional[Dict[str, Any]] = None,
        json_body: Optional[Dict[str, Any]] = None,
        data: Optional[bytes] = None,
        headers: Optional[Dict[str, str]] = None,
        cost: int = 1,
        base_url: Optional[str] = None,
        require_auth: bool = True,
    ) -> YouTubeResponse:
        """Perform an authenticated request with rate limiting and retries."""
        if require_auth and self.oauth is None and not self.api_key:
            raise AuthenticationError(
                401, "noCredentials", "An OAuth2 client or API key is required"
            )

        base = base_url or self.base_url
        query = dict(params or {})
        if self.api_key and "key" not in query:
            query["key"] = self.api_key
        url = base + path
        if query:
            url = url + "?" + urllib.parse.urlencode(
                {k: v for k, v in query.items() if v is not None}
            )

        req_headers = self._auth_headers() if require_auth else {"Accept": "application/json"}
        if headers:
            req_headers.update(headers)
        if json_body is not None:
            data = json.dumps(json_body).encode("utf-8")
            req_headers["Content-Type"] = "application/json"
        elif data is not None and "Content-Type" not in req_headers:
            req_headers["Content-Type"] = "application/octet-stream"

        attempt = 0
        while True:
            self.rate_limiter.acquire(cost)
            request = urllib.request.Request(
                url, data=data, headers=req_headers, method=method.upper()
            )
            try:
                status, resp_headers, raw = self.transport.send(request)
            except urllib.error.URLError as exc:  # network-level failure
                if attempt < self.retry_policy.max_retries:
                    self.retry_policy.sleep_func(self.retry_policy.compute_backoff(attempt))
                    attempt += 1
                    continue
                raise YouTubeError(f"Network error contacting YouTube: {exc}") from exc

            body = _decode_body(raw)
            if 200 <= status < 300:
                return YouTubeResponse(status=status, body=body, headers=resp_headers)

            error = _error_from_payload(status, body)
            if self.retry_policy.should_retry(status, attempt):
                self.retry_policy.sleep_func(self.retry_policy.compute_backoff(attempt))
                attempt += 1
                continue
            raise error

    # -- Channels --------------------------------------------------------
    def get_channel(
        self,
        channel_id: Optional[str] = None,
        for_handle: Optional[str] = None,
        mine: bool = False,
        part: Iterable[str] = ("snippet", "statistics", "contentDetails"),
    ) -> Channel:
        params: Dict[str, Any] = {"part": ",".join(part)}
        if channel_id:
            params["id"] = channel_id
        elif for_handle:
            params["forHandle"] = for_handle
        elif mine:
            params["mine"] = "true"
        else:
            raise BadRequestError(400, "missingId", "channel_id, for_handle or mine required")
        resp = self.request("GET", "/channels", params=params)
        item = resp.first()
        if not item:
            raise NotFoundError(404, "channelNotFound", "Channel not found")
        return Channel.from_api(item)

    def list_channels(
        self,
        ids: Optional[Iterable[str]] = None,
        category_id: Optional[str] = None,
        mine: bool = False,
        max_results: int = 25,
        page_token: Optional[str] = None,
        part: Iterable[str] = ("snippet", "statistics"),
    ) -> YouTubeResponse:
        params: Dict[str, Any] = {
            "part": ",".join(part),
            "maxResults": max(1, min(50, max_results)),
        }
        if ids:
            params["id"] = ",".join(ids)
        if category_id:
            params["categoryId"] = category_id
        if mine:
            params["mine"] = "true"
        if page_token:
            params["pageToken"] = page_token
        return self.request("GET", "/channels", params=params)

    # -- Videos ----------------------------------------------------------
    def get_video(
        self,
        video_id: str,
        part: Iterable[str] = ("snippet", "statistics", "status", "contentDetails"),
    ) -> Video:
        resp = self.request("GET", "/videos", params={"part": ",".join(part), "id": video_id})
        item = resp.first()
        if not item:
            raise NotFoundError(404, "videoNotFound", f"Video {video_id} not found")
        return Video.from_api(item)

    def list_videos(
        self,
        ids: Optional[Iterable[str]] = None,
        chart: Optional[str] = None,
        region_code: Optional[str] = None,
        my_rating: bool = False,
        max_results: int = 25,
        page_token: Optional[str] = None,
        part: Iterable[str] = ("snippet", "statistics"),
    ) -> YouTubeResponse:
        params: Dict[str, Any] = {
            "part": ",".join(part),
            "maxResults": max(1, min(50, max_results)),
        }
        if ids:
            params["id"] = ",".join(ids)
        if chart:
            params["chart"] = chart
        if region_code:
            params["regionCode"] = region_code
        if my_rating:
            params["myRating"] = "like"
        if page_token:
            params["pageToken"] = page_token
        return self.request("GET", "/videos", params=params)

    def search(
        self,
        query: str,
        channel_id: Optional[str] = None,
        type: str = "video",
        max_results: int = 25,
        page_token: Optional[str] = None,
        order: str = "relevance",
    ) -> YouTubeResponse:
        params: Dict[str, Any] = {
            "part": "snippet",
            "q": query,
            "type": type,
            "order": order,
            "maxResults": max(1, min(50, max_results)),
        }
        if channel_id:
            params["channelId"] = channel_id
        if page_token:
            params["pageToken"] = page_token
        return self.request("GET", "/search", params=params)

    def update_video(
        self,
        video_id: str,
        snippet: Optional[Dict[str, Any]] = None,
        status: Optional[Dict[str, Any]] = None,
    ) -> Video:
        body: Dict[str, Any] = {"id": video_id}
        parts = []
        if snippet is not None:
            body["snippet"] = snippet
            parts.append("snippet")
        if status is not None:
            body["status"] = status
            parts.append("status")
        if not parts:
            raise BadRequestError(400, "noParts", "At least one of snippet/status required")
        resp = self.request(
            "PUT", "/videos", params={"part": ",".join(parts)}, json_body=body
        )
        return Video.from_api(_resource_from_response(resp))

    def delete_video(self, video_id: str) -> YouTubeResponse:
        return self.request("DELETE", "/videos", params={"id": video_id})

    # -- Video upload ----------------------------------------------------
    def _upload_metadata(
        self,
        title: str,
        description: str = "",
        tags: Optional[Iterable[str]] = None,
        privacy_status: str = "private",
        category_id: str = "22",
        made_for_kids: bool = False,
    ) -> Dict[str, Any]:
        """Build the ``videos#resource`` body for an upload."""
        snippet: Dict[str, Any] = {
            "title": title,
            "description": description,
            "categoryId": category_id,
        }
        if tags:
            snippet["tags"] = list(tags)
        return {
            "snippet": snippet,
            "status": {
                "privacyStatus": privacy_status,
                "selfDeclaredMadeForKids": made_for_kids,
            },
        }

    def initiate_resumable_upload(
        self,
        metadata: Dict[str, Any],
        content_type: str = "video/*",
        content_length: Optional[int] = None,
    ) -> str:
        """Start a resumable upload session and return the upload URL.

        The returned URL is then used with :meth:`upload_chunk` /
        :meth:`upload_bytes` to transfer the media.
        """
        headers = {
            "X-Upload-Content-Type": content_type,
            "Content-Type": "application/json; charset=UTF-8",
        }
        if content_length is not None:
            headers["X-Upload-Content-Length"] = str(content_length)
        resp = self.request(
            "POST",
            "/videos",
            params={"part": "snippet,status", "uploadType": "resumable"},
            json_body=metadata,
            headers=headers,
            base_url=self.upload_url,
            cost=1,
        )
        location = resp.headers.get("Location") or resp.headers.get("location")
        if not location:
            raise YouTubeAPIError(
                resp.status or 0,
                "missingUploadUrl",
                "Resumable upload did not return a Location header",
            )
        return location

    def upload_chunk(
        self,
        upload_url: str,
        data: bytes,
        content_range: str,
        total_size: Optional[int] = None,
    ) -> YouTubeResponse:
        """Upload a single chunk of a resumable session.

        ``content_range`` follows the ``bytes start-end/total`` convention, e.g.
        ``"bytes 0-262143/1048576"``. Use ``total`` of ``"*"`` when unknown.
        """
        headers = {
            "Content-Length": str(len(data)),
            "Content-Range": content_range,
        }
        request = urllib.request.Request(
            upload_url, data=data, headers=headers, method="PUT"
        )
        request.add_header("Authorization", f"Bearer {self.oauth.get_access_token()}")
        self.rate_limiter.acquire(0)
        status, resp_headers, raw = self.transport.send(request)
        body = _decode_body(raw)
        if 200 <= status < 300 or status == 308:
            return YouTubeResponse(status=status, body=body, headers=resp_headers)
        raise _error_from_payload(status, body)

    def upload_bytes(
        self,
        upload_url: str,
        media: bytes,
        chunk_size: int = 256 * 1024,
    ) -> YouTubeResponse:
        """Upload ``media`` to ``upload_url`` in ``chunk_size`` chunks."""
        total = len(media)
        offset = 0
        last: Optional[YouTubeResponse] = None
        while offset < total or total == 0:
            end = min(offset + chunk_size, total) - 1
            chunk = media[offset : offset + chunk_size]
            content_range = f"bytes {offset}-{end}/{total}"
            last = self.upload_chunk(upload_url, chunk, content_range, total)
            offset = end + 1
            if total == 0:
                break
        assert last is not None
        return last

    def upload_video(
        self,
        title: str,
        media: bytes,
        description: str = "",
        tags: Optional[Iterable[str]] = None,
        privacy_status: str = "private",
        category_id: str = "22",
        content_type: str = "video/*",
        chunk_size: int = 256 * 1024,
    ) -> Video:
        """End-to-end resumable upload of a video from bytes.

        Returns the created :class:`Video`.
        """
        metadata = self._upload_metadata(
            title=title,
            description=description,
            tags=tags,
            privacy_status=privacy_status,
            category_id=category_id,
        )
        upload_url = self.initiate_resumable_upload(
            metadata, content_type=content_type, content_length=len(media)
        )
        resp = self.upload_bytes(upload_url, media, chunk_size=chunk_size)
        return Video.from_api(_resource_from_response(resp))

    # -- Playlists -------------------------------------------------------
    def get_playlist(self, playlist_id: str) -> Playlist:
        resp = self.request("GET", "/playlists", params={"part": "snippet,status,contentDetails", "id": playlist_id})
        item = resp.first()
        if not item:
            raise NotFoundError(404, "playlistNotFound", f"Playlist {playlist_id} not found")
        return Playlist.from_api(item)

    def list_playlists(
        self,
        channel_id: Optional[str] = None,
        mine: bool = False,
        max_results: int = 25,
        page_token: Optional[str] = None,
    ) -> YouTubeResponse:
        params: Dict[str, Any] = {
            "part": "snippet,status,contentDetails",
            "maxResults": max(1, min(50, max_results)),
        }
        if channel_id:
            params["channelId"] = channel_id
        if mine:
            params["mine"] = "true"
        if page_token:
            params["pageToken"] = page_token
        return self.request("GET", "/playlists", params=params)

    def create_playlist(
        self,
        title: str,
        description: str = "",
        privacy_status: str = "private",
    ) -> Playlist:
        body = {
            "snippet": {"title": title, "description": description},
            "status": {"privacyStatus": privacy_status},
        }
        resp = self.request("POST", "/playlists", params={"part": "snippet,status"}, json_body=body)
        return Playlist.from_api(_resource_from_response(resp))

    def update_playlist(
        self,
        playlist_id: str,
        title: Optional[str] = None,
        description: Optional[str] = None,
        privacy_status: Optional[str] = None,
    ) -> Playlist:
        snippet: Dict[str, Any] = {}
        if title is not None:
            snippet["title"] = title
        if description is not None:
            snippet["description"] = description
        body: Dict[str, Any] = {"id": playlist_id, "snippet": snippet}
        parts = ["snippet"]
        if privacy_status is not None:
            body["status"] = {"privacyStatus": privacy_status}
            parts.append("status")
        resp = self.request(
            "PUT", "/playlists", params={"part": ",".join(parts)}, json_body=body
        )
        return Playlist.from_api(_resource_from_response(resp))

    def delete_playlist(self, playlist_id: str) -> YouTubeResponse:
        return self.request("DELETE", "/playlists", params={"id": playlist_id})

    # -- Playlist items --------------------------------------------------
    def list_playlist_items(
        self,
        playlist_id: str,
        max_results: int = 25,
        page_token: Optional[str] = None,
    ) -> YouTubeResponse:
        params: Dict[str, Any] = {
            "part": "snippet,contentDetails",
            "playlistId": playlist_id,
            "maxResults": max(1, min(50, max_results)),
        }
        if page_token:
            params["pageToken"] = page_token
        return self.request("GET", "/playlistItems", params=params)

    def add_video_to_playlist(
        self, playlist_id: str, video_id: str, position: Optional[int] = None
    ) -> PlaylistItem:
        snippet: Dict[str, Any] = {
            "playlistId": playlist_id,
            "resourceId": {"kind": "youtube#video", "videoId": video_id},
        }
        if position is not None:
            snippet["position"] = position
        resp = self.request(
            "POST", "/playlistItems", params={"part": "snippet"}, json_body={"snippet": snippet}
        )
        return PlaylistItem.from_api(_resource_from_response(resp))

    def delete_playlist_item(self, item_id: str) -> YouTubeResponse:
        return self.request("DELETE", "/playlistItems", params={"id": item_id})

    # -- Live streams ----------------------------------------------------
    def create_live_stream(
        self,
        title: str,
        description: str = "",
        resolution: str = "1080p",
        frame_rate: str = "30fps",
        ingestion_type: str = "rtmp",
        is_4k: bool = False,
    ) -> LiveStream:
        """Create a new live stream resource with ingestion settings."""
        body = {
            "snippet": {"title": title, "description": description},
            "cdn": {
                "frameRate": frame_rate,
                "ingestionType": ingestion_type,
                "resolution": resolution,
            },
            "status": {"privacyStatus": "private"},
        }
        if is_4k:
            body["cdn"]["resolution"] = "2160p"
        resp = self.request(
            "POST", "/liveStreams", params={"part": "snippet,cdn,status"}, json_body=body
        )
        return LiveStream.from_api(_resource_from_response(resp))

    def get_live_stream(self, stream_id: str) -> LiveStream:
        resp = self.request(
            "GET",
            "/liveStreams",
            params={"part": "snippet,cdn,status", "id": stream_id},
        )
        item = resp.first()
        if not item:
            raise NotFoundError(404, "liveStreamNotFound", f"Live stream {stream_id} not found")
        return LiveStream.from_api(item)

    def list_live_streams(
        self, mine: bool = True, stream_ids: Optional[Iterable[str]] = None, max_results: int = 25
    ) -> YouTubeResponse:
        params: Dict[str, Any] = {
            "part": "snippet,cdn,status",
            "maxResults": max(1, min(50, max_results)),
        }
        if stream_ids:
            params["id"] = ",".join(stream_ids)
        elif mine:
            params["mine"] = "true"
        return self.request("GET", "/liveStreams", params=params)

    def update_live_stream(self, stream_id: str, title: Optional[str] = None) -> LiveStream:
        snippet: Dict[str, Any] = {}
        if title is not None:
            snippet["title"] = title
        resp = self.request(
            "PUT",
            "/liveStreams",
            params={"part": "snippet"},
            json_body={"id": stream_id, "snippet": snippet},
        )
        return LiveStream.from_api(_resource_from_response(resp))

    def delete_live_stream(self, stream_id: str) -> YouTubeResponse:
        return self.request("DELETE", "/liveStreams", params={"id": stream_id})

    def get_stream_health(self, stream_id: str) -> StreamHealth:
        """Fetch and aggregate the health snapshot for a live stream."""
        resp = self.request(
            "GET",
            "/liveStreams",
            params={"part": "status,statistics", "id": stream_id},
        )
        item = resp.first()
        if not item:
            raise NotFoundError(404, "liveStreamNotFound", f"Live stream {stream_id} not found")
        return StreamHealth.from_api(item)

    # -- Live broadcasts -------------------------------------------------
    def create_live_broadcast(
        self,
        title: str,
        description: str = "",
        scheduled_start_time: Optional[str] = None,
        privacy_status: str = "private",
        stream_id: Optional[str] = None,
    ) -> LiveBroadcast:
        """Create a live broadcast, optionally binding it to a stream."""
        snippet: Dict[str, Any] = {"title": title, "description": description}
        if scheduled_start_time:
            snippet["scheduledStartTime"] = scheduled_start_time
        body: Dict[str, Any] = {
            "snippet": snippet,
            "status": {"privacyStatus": privacy_status, "selfDeclaredMadeForKids": False},
        }
        if stream_id:
            body["contentDetails"] = {"boundStreamId": stream_id}
        resp = self.request(
            "POST",
            "/liveBroadcasts",
            params={"part": "snippet,status,contentDetails"},
            json_body=body,
        )
        return LiveBroadcast.from_api(_resource_from_response(resp))

    def get_live_broadcast(self, broadcast_id: str) -> LiveBroadcast:
        resp = self.request(
            "GET",
            "/liveBroadcasts",
            params={"part": "snippet,status,contentDetails", "id": broadcast_id},
        )
        item = resp.first()
        if not item:
            raise NotFoundError(
                404, "liveBroadcastNotFound", f"Live broadcast {broadcast_id} not found"
            )
        return LiveBroadcast.from_api(item)

    def list_live_broadcasts(
        self,
        mine: bool = True,
        broadcast_status: str = BroadcastStatus.ALL.value,
        max_results: int = 25,
        page_token: Optional[str] = None,
    ) -> YouTubeResponse:
        params: Dict[str, Any] = {
            "part": "snippet,status,contentDetails",
            "broadcastStatus": broadcast_status,
            "maxResults": max(1, min(50, max_results)),
        }
        if mine:
            params["mine"] = "true"
        if page_token:
            params["pageToken"] = page_token
        return self.request("GET", "/liveBroadcasts", params=params)

    def update_live_broadcast(
        self,
        broadcast_id: str,
        title: Optional[str] = None,
        description: Optional[str] = None,
        privacy_status: Optional[str] = None,
    ) -> LiveBroadcast:
        snippet: Dict[str, Any] = {}
        if title is not None:
            snippet["title"] = title
        if description is not None:
            snippet["description"] = description
        body: Dict[str, Any] = {"id": broadcast_id, "snippet": snippet}
        parts = ["snippet"]
        if privacy_status is not None:
            body["status"] = {"privacyStatus": privacy_status}
            parts.append("status")
        resp = self.request(
            "PUT",
            "/liveBroadcasts",
            params={"part": ",".join(parts)},
            json_body=body,
        )
        return LiveBroadcast.from_api(_resource_from_response(resp))

    def delete_live_broadcast(self, broadcast_id: str) -> YouTubeResponse:
        return self.request("DELETE", "/liveBroadcasts", params={"id": broadcast_id})

    def transition_broadcast(
        self, broadcast_id: str, status: BroadcastTransition, stream_id: Optional[str] = None
    ) -> LiveBroadcast:
        """Transition a broadcast through its lifecycle (testing -> live -> complete).

        This is the core of the automated stream-transition workflow: a
        broadcast is first created in the ``testing`` state, then promoted to
        ``live`` once the stream is healthy, and finally ``complete``d.
        """
        status_value = status.value if isinstance(status, BroadcastTransition) else str(status)
        params: Dict[str, Any] = {
            "part": "snippet,status",
            "id": broadcast_id,
            "broadcastStatus": status_value,
        }
        if stream_id:
            params["streamId"] = stream_id
        resp = self.request("POST", "/liveBroadcasts/transition", params=params)
        return LiveBroadcast.from_api(_resource_from_response(resp))

    # -- Live chat -------------------------------------------------------
    def get_live_chat_messages(
        self,
        live_chat_id: str,
        max_results: int = 200,
        page_token: Optional[str] = None,
        profile_image_size: int = 88,
    ) -> YouTubeResponse:
        params: Dict[str, Any] = {
            "part": "snippet,authorDetails",
            "liveChatId": live_chat_id,
            "maxResults": max(1, min(2000, max_results)),
            "profileImageSize": profile_image_size,
        }
        if page_token:
            params["pageToken"] = page_token
        return self.request("GET", "/liveChat/messages", params=params)

    def send_live_chat_message(self, live_chat_id: str, text: str) -> LiveChatMessage:
        """Post a text message to a live chat."""
        body = {
            "snippet": {
                "liveChatId": live_chat_id,
                "type": "textMessageEvent",
                "textMessageDetails": {"messageText": text},
            }
        }
        resp = self.request(
            "POST", "/liveChat/messages", params={"part": "snippet"}, json_body=body
        )
        return LiveChatMessage.from_api(_resource_from_response(resp))

    def list_chat_messages(
        self, live_chat_id: str, max_results: int = 200, page_token: Optional[str] = None
    ) -> List[LiveChatMessage]:
        """Return parsed :class:`LiveChatMessage` objects for a live chat."""
        resp = self.get_live_chat_messages(
            live_chat_id, max_results=max_results, page_token=page_token
        )
        return [LiveChatMessage.from_api(item) for item in resp.items()]

    def poll_chat_once(
        self, live_chat_id: str, seen_ids: Optional[set] = None
    ) -> Tuple[List[LiveChatMessage], Optional[str]]:
        """Poll a live chat once, returning ``(new_messages, next_page_token)``.

        ``seen_ids`` is mutated in place to track already-seen message ids so
        callers can implement incremental polling loops without duplicates.
        """
        if seen_ids is None:
            seen_ids = set()
        messages = self.list_chat_messages(live_chat_id)
        fresh = [m for m in messages if m.id not in seen_ids]
        for m in fresh:
            seen_ids.add(m.id)
        resp = self.get_live_chat_messages(live_chat_id)
        return fresh, resp.body.get("nextPageToken")


# ---------------------------------------------------------------------------
# High-level facade
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# Webhook plumbing (PubSubHubbub / Google PubSubHubbub push notifications)
# ---------------------------------------------------------------------------

# YouTube's push notification hub. Channel updates (new videos, live-stream
# state changes) are delivered as Atom feeds to a registered callback URL.
PUBSUB_HUB_URL = "https://pubsubhubbub.appspot.com/"

# Atom namespaces used by YouTube's PubSubHubbub feeds.
_ATOM_NS = "http://www.w3.org/2005/Atom"
_YT_NS = "http://www.youtube.com/xml/schemas/2010"
_MEDIA_NS = "http://search.yahoo.com/mrss/"


@dataclass
class WebhookVerification:
    """Result of a PubSubHubbub subscription (subscribe/unsubscribe) request."""

    mode: str
    topic: str
    callback_url: str
    challenge: str = ""
    verified: bool = True
    lease_seconds: Optional[int] = None
    raw: Dict[str, Any] = field(default_factory=dict)


@dataclass
class WebhookNotification:
    """A parsed PubSubHubbub push notification for a YouTube channel feed."""

    channel_id: str = ""
    video_id: str = ""
    title: str = ""
    link: str = ""
    author: str = ""
    published: str = ""
    updated: str = ""
    media_group: Dict[str, Any] = field(default_factory=dict)
    raw_xml: str = ""

    @property
    def is_video_upload(self) -> bool:
        """True when the notification carries a video entry."""
        return bool(self.video_id)

    @classmethod
    def from_xml(cls, xml_text: str) -> "WebhookNotification":
        """Parse an Atom feed payload into a :class:`WebhookNotification`.

        Raises :class:`YouTubeError` if the payload is not well-formed XML.
        """
        try:
            root = ET.fromstring(xml_text)
        except ET.ParseError as exc:  # pragma: no cover - defensive
            raise YouTubeError(f"Invalid webhook XML: {exc}") from exc

        def _find_text(el: ET.Element, path: str) -> str:
            found = el.find(path, {"atom": _ATOM_NS, "yt": _YT_NS, "media": _MEDIA_NS})
            return (found.text or "").strip() if found is not None else ""

        entry = root.find("atom:entry", {"atom": _ATOM_NS})
        if entry is None:
            # Some payloads are the feed root itself.
            entry = root

        channel_id = _find_text(entry, "atom:author/atom:uri/atom:channelId") or _find_text(
            entry, "yt:channelId"
        )
        video_id = _find_text(entry, "yt:videoId")
        title = _find_text(entry, "atom:title")
        link_el = entry.find("atom:link", {"atom": _ATOM_NS})
        link = link_el.get("href", "") if link_el is not None else ""
        author = _find_text(entry, "atom:author/atom:name")
        published = _find_text(entry, "atom:published")
        updated = _find_text(entry, "atom:updated")

        media_group: Dict[str, Any] = {}
        group_el = entry.find("media:group", {"media": _MEDIA_NS})
        if group_el is not None:
            for child in group_el:
                tag = child.tag.split("}")[-1]
                media_group[tag] = (child.text or "").strip()

        return cls(
            channel_id=channel_id,
            video_id=video_id,
            title=title,
            link=link,
            author=author,
            published=published,
            updated=updated,
            media_group=media_group,
            raw_xml=xml_text,
        )


class WebhookVerifier:
    """Verifies the authenticity of inbound webhook requests.

    YouTube's PubSubHubbub hub does not sign payloads, but deployments commonly
    front the callback with a shared secret. This helper supports constant-time
    HMAC-SHA1 / HMAC-SHA256 header verification (``X-Hub-Signature``) so agents
    can reject spoofed notifications.
    """

    def __init__(self, secret: bytes) -> None:
        if isinstance(secret, str):
            secret = secret.encode("utf-8")
        self._secret = secret

    def _digest(self, body: bytes, algo: str) -> str:
        h = hmac.new(self._secret, body, getattr(hashlib, algo))
        return h.hexdigest()

    def signature(self, body: bytes, algo: str = "sha256") -> str:
        """Compute the ``sha1=``/``sha256=`` signature for ``body``."""
        return f"{algo}={self._digest(body, algo)}"

    def verify(
        self, body: bytes, signature_header: Optional[str], algo: str = "sha256"
    ) -> bool:
        """Constant-time check of ``signature_header`` against ``body``."""
        if not signature_header:
            return False
        expected = self.signature(body, algo)
        return hmac.compare_digest(expected, signature_header)


class PubSubHubbub:
    """Client for managing YouTube PubSubHubbub webhook subscriptions.

    YouTube channel feeds are push-subscribed through the Google PubSubHubbub
    hub. This class builds the subscribe/unsubscribe callbacks and parses the
    Atom notifications the hub delivers. Network delivery is left to the host
    application (e.g. a Lux beam or web server); this class is transport-free
    and therefore fully unit-testable offline.
    """

    def __init__(self, hub_url: str = PUBSUB_HUB_URL) -> None:
        self.hub_url = hub_url

    def topic_url(self, channel_id: str) -> str:
        """Return the Atom feed topic URL for ``channel_id``."""
        return (
            "https://pubsubhubbub.appspot.com/subscribe/"
            f"https://www.youtube.com/xml/feeds/videos.xml?channel_id={channel_id}"
        )

    def verify_request(
        self,
        mode: str,
        topic: str,
        callback_url: str,
        challenge: str,
        lease_seconds: Optional[int] = None,
    ) -> WebhookVerification:
        """Build the verification challenge response for a hub handshake.

        Per the PubSubHubbub spec the subscriber must echo the ``challenge``
        value back as the raw HTTP response body when ``hub.mode`` is
        ``subscribe`` or ``unsubscribe``.
        """
        return WebhookVerification(
            mode=mode,
            topic=topic,
            callback_url=callback_url,
            challenge=challenge,
            verified=mode in ("subscribe", "unsubscribe"),
            lease_seconds=lease_seconds,
            raw={
                "hub.mode": mode,
                "hub.topic": topic,
                "hub.callback": callback_url,
                "hub.challenge": challenge,
                "hub.lease_seconds": lease_seconds,
            },
        )

    def subscription_params(
        self,
        channel_id: str,
        callback_url: str,
        mode: str = "subscribe",
        lease_seconds: Optional[int] = None,
    ) -> Dict[str, str]:
        """Return the form parameters for a hub subscribe/unsubscribe request."""
        params = {
            "hub.callback": callback_url,
            "hub.mode": mode,
            "hub.topic": self.topic_url(channel_id),
            "hub.verify": "async",
        }
        if lease_seconds is not None:
            params["hub.lease_seconds"] = str(lease_seconds)
        return params

    def parse_notification(self, body: bytes) -> WebhookNotification:
        """Parse a raw Atom push notification body."""
        if isinstance(body, bytes):
            body = body.decode("utf-8")
        return WebhookNotification.from_xml(body)

    def verify_signature(
        self,
        body: bytes,
        signature_header: Optional[str],
        secret: bytes,
        algo: str = "sha256",
    ) -> bool:
        """Convenience wrapper around :class:`WebhookVerifier`."""
        return WebhookVerifier(secret).verify(body, signature_header, algo)


class YouTubeCore:
    """High-level facade bundling OAuth2 + the YouTube client.

    This is the primary entry point Lux agents should use. It owns the OAuth2
    helper and the low-level :class:`YouTubeClient`, and exposes convenience
    methods for the most common end-to-end workflows (e.g. "create a
    scheduled broadcast bound to a fresh stream and take it live").

    Parameters
    ----------
    config:
        An :class:`OAuth2Config` with client credentials and scopes.
    transport:
        Optional HTTP transport (shared by OAuth2 and the API client).
    api_key:
        Optional API key for read-only requests.
    token_store:
        Optional dict used to persist/load the token set between runs.
    """

    def __init__(
        self,
        config: OAuth2Config,
        transport: Optional[Transport] = None,
        api_key: Optional[str] = None,
        token_store: Optional[Dict[str, Any]] = None,
        rate_limiter: Optional[RateLimiter] = None,
        retry_policy: Optional[RetryPolicy] = None,
    ) -> None:
        self.transport = transport or UrllibTransport()
        self.oauth = OAuth2(config, transport=self.transport, token_store=token_store)
        self.client = YouTubeClient(
            oauth=self.oauth,
            api_key=api_key,
            transport=self.transport,
            rate_limiter=rate_limiter,
            retry_policy=retry_policy,
        )

    # -- auth passthrough ------------------------------------------------
    @property
    def authorization_url(self) -> str:
        return self.oauth.authorization_url()

    def authenticate_with_code(self, code: str) -> TokenSet:
        return self.oauth.exchange_code(code)

    @property
    def is_authenticated(self) -> bool:
        return self.oauth.token is not None

    # -- resource passthroughs ------------------------------------------
    def get_channel(self, channel_id: Optional[str] = None, **kwargs) -> Channel:
        return self.client.get_channel(channel_id=channel_id, **kwargs)

    def get_video(self, video_id: str) -> Video:
        return self.client.get_video(video_id)

    def search(self, query: str, **kwargs) -> YouTubeResponse:
        return self.client.search(query, **kwargs)

    def create_playlist(self, title: str, **kwargs) -> Playlist:
        return self.client.create_playlist(title, **kwargs)

    # -- end-to-end live workflow ---------------------------------------
    def create_scheduled_broadcast(
        self,
        title: str,
        description: str = "",
        scheduled_start_time: Optional[str] = None,
        privacy_status: str = "private",
        resolution: str = "1080p",
        frame_rate: str = "30fps",
    ) -> Tuple[LiveStream, LiveBroadcast]:
        """Create a stream + bound broadcast in one call.

        Returns the ``(stream, broadcast)`` pair. The broadcast is created in
        the ``upcoming`` state; call :meth:`go_live` to take it live.
        """
        stream = self.client.create_live_stream(
            title=title, resolution=resolution, frame_rate=frame_rate
        )
        broadcast = self.client.create_live_broadcast(
            title=title,
            description=description,
            scheduled_start_time=scheduled_start_time,
            privacy_status=privacy_status,
            stream_id=stream.id,
        )
        return stream, broadcast

    def go_live(
        self, broadcast_id: str, stream_id: str, wait_healthy: bool = False
    ) -> LiveBroadcast:
        """Transition a broadcast to ``live`` (optionally waiting for health)."""
        if wait_healthy:
            self.wait_for_stream_healthy(stream_id)
        return self.client.transition_broadcast(
            broadcast_id, BroadcastTransition.LIVE, stream_id=stream_id
        )

    def end_broadcast(self, broadcast_id: str) -> LiveBroadcast:
        """Transition a broadcast to its ``complete`` (ended) state."""
        return self.client.transition_broadcast(broadcast_id, BroadcastTransition.COMPLETE)

    def wait_for_stream_healthy(
        self, stream_id: str, timeout: float = 300.0, interval: float = 5.0
    ) -> StreamHealth:
        """Poll a stream's health until it is healthy or ``timeout`` elapses.

        Returns the final :class:`StreamHealth`. Raises :class:`YouTubeError`
        if the stream does not become healthy within ``timeout`` seconds.
        """
        deadline = time.monotonic() + timeout
        last: Optional[StreamHealth] = None
        while time.monotonic() < deadline:
            last = self.client.get_stream_health(stream_id)
            if last.is_healthy:
                return last
            time.sleep(interval)
        raise YouTubeError(
            f"Stream {stream_id} did not become healthy within {timeout}s"
        )
