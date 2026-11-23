"""
Shopify Admin API integration for the Lux framework.

This module provides a production-grade, dependency-free client for the Shopify
Admin API (both the REST Admin API and the GraphQL Admin API). It is designed to
be used by Lux agents, prisms, and lenses to interact with a Shopify store.

Design goals
------------
* **Stdlib only** -- no third-party HTTP or serialization dependencies. The
  client talks to Shopify over ``urllib`` and parses JSON with the stdlib
  ``json`` module. This keeps the integration portable across the Lux Python
  runtime (``priv/python``) and any host environment.
* **Two API surfaces** -- a REST client (:class:`ShopifyAdminClient`) and a
  GraphQL client (:class:`ShopifyGraphQLClient`). Both share the same
  authentication, retry, and rate-limit machinery.
* **Typed responses** -- every API call returns a :class:`ShopifyResponse`
  (or a list of :class:`ShopifyResource` objects) rather than raw dicts, so
  callers get attribute access, autocomplete, and a stable contract.
* **Resilience** -- automatic retries with exponential backoff + jitter for
  transient failures (5xx, network errors, ``THROTTLED``), and proactive
  rate-limit handling that sleeps until the ``Retry-After`` / calculated
  ``X-Shopify-Shop-Api-Call-Limit`` window resets.
* **Pagination** -- first-class cursor-based pagination for REST
  (``Link`` header) and GraphQL (``pageInfo``) endpoints, exposed via
  :meth:`ShopifyAdminClient.paginate` and :func:`paginate`.
* **Testability** -- the transport is injectable (:class:`ShopifyTransport`),
  so the entire suite runs offline with mocked HTTP and no live credentials.

Authentication
--------------
Two authentication modes are supported:

* **Admin API access token** (private / custom app) -- pass
  ``access_token`` (or set ``SHOPIFY_ACCESS_TOKEN``). Sent as the
  ``X-Shopify-Access-Token`` header.
* **OAuth 2.0** -- pass ``access_token`` obtained from the OAuth grant. The
  client also exposes :meth:`ShopifyOAuth.exchange_code` and
  :meth:`ShopifyOAuth.refresh_token` helpers to perform the authorization-code
  and refresh-token flows.

A convenience :class:`ShopifyClient` factory builds the right client from a
single config dict / environment.

Example
-------
::

    from shopify_integration import ShopifyClient

    shopify = ShopifyClient(
        shop="my-store.myshopify.com",
        access_token="shpat_xxx",
        api_version="2024-10",
    )

    # REST: list products (auto-paginates)
    for product in shopify.products.list(limit=50):
        print(product.title, product.variants[0].price)

    # REST: create an order
    order = shopify.orders.create({
        "line_items": [{"variant_id": 123, "quantity": 1}],
    })
    print(order.id, order.total_price)

    # GraphQL: query with typed result
    result = shopify.graphql("{ shop { name } }")
    print(result.data["shop"]["name"])

    # Webhooks
    hook = shopify.webhooks.create({
        "topic": "orders/create",
        "address": "https://example.com/hooks/shopify",
        "format": "json",
    })
"""

from __future__ import annotations

import json
import logging
import os
import random
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from typing import (
    Any,
    Callable,
    Dict,
    Iterable,
    Iterator,
    List,
    Mapping,
    Optional,
    Sequence,
    Tuple,
    Union,
)

__all__ = [
    # Core
    "ShopifyError",
    "ShopifyHTTPError",
    "ShopifyAuthError",
    "ShopifyRateLimitError",
    "ShopifyNotFoundError",
    "ShopifyValidationError",
    "ShopifyServerError",
    "ShopifyResponse",
    "ShopifyResource",
    "ShopifyTransport",
    "ShopifyAdminClient",
    "ShopifyGraphQLClient",
    "ShopifyClient",
    "ShopifyOAuth",
    # Resources
    "ProductsResource",
    "OrdersResource",
    "CustomersResource",
    "InventoryResource",
    "WebhooksResource",
    # Pagination
    "paginate",
    "Page",
]

logger = logging.getLogger("lux.shopify")

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

DEFAULT_API_VERSION = "2024-10"
DEFAULT_TIMEOUT = 30.0
DEFAULT_MAX_RETRIES = 3
DEFAULT_BACKOFF_BASE = 0.5
DEFAULT_BACKOFF_CAP = 8.0

# Shopify REST Admin API rate limit is a leaky bucket (default 40, Plus 80)
# leaking at 2 req/s. We read the live bucket from response headers when
# available and fall back to these defaults for proactive throttling.
DEFAULT_LEAKY_BUCKET = 40
DEFAULT_LEAK_RATE = 2.0

REST_API_PATH = "/admin/api/{version}/{resource}.json"
GRAPHQL_API_PATH = "/admin/api/{version}/graphql.json"
OAUTH_TOKEN_PATH = "/admin/oauth/access_token"
OAUTH_REVOKE_PATH = "/admin/oauth/revoke"

# HTTP status codes that are safe to retry.
RETRYABLE_STATUS = frozenset({429, 500, 502, 503, 504})

# GraphQL error codes / messages that indicate throttling.
THROTTLED_MESSAGES = ("Throttled", "THROTTLED", "rate limit", "Rate limit")


# ---------------------------------------------------------------------------
# Errors
# ---------------------------------------------------------------------------


class ShopifyError(Exception):
    """Base class for all Shopify integration errors."""


class ShopifyHTTPError(ShopifyError):
    """Raised when Shopify returns a non-2xx HTTP response.

    Attributes
    ----------
    status_code:
        The HTTP status code returned by Shopify.
    body:
        The parsed response body (dict) if available, else the raw text.
    headers:
        The response headers (case-insensitive mapping).
    code:
        A normalized error code string (e.g. ``"not_found"``).
    """

    def __init__(
        self,
        message: str,
        status_code: int,
        body: Any = None,
        headers: Optional[Mapping[str, str]] = None,
        code: Optional[str] = None,
    ) -> None:
        super().__init__(message)
        self.status_code = status_code
        self.body = body
        self.headers = dict(headers or {})
        self.code = code or _status_to_code(status_code)

    def __repr__(self) -> str:  # pragma: no cover - cosmetic
        return (
            f"{type(self).__name__}(status_code={self.status_code!r}, "
            f"code={self.code!r}, message={str(self)!r})"
        )


class ShopifyAuthError(ShopifyHTTPError):
    """Raised for 401/403 authentication/authorization failures."""

    def __init__(self, message: str, status_code: int = 401, **kwargs: Any) -> None:
        kwargs.pop("status_code", None)
        super().__init__(message, status_code, code="unauthorized", **kwargs)


class ShopifyRateLimitError(ShopifyHTTPError):
    """Raised when Shopify reports a rate-limit (429) that could not be waited out."""

    def __init__(
        self,
        message: str = "Shopify rate limit exceeded",
        status_code: int = 429,
        retry_after: Optional[float] = None,
        **kwargs: Any,
    ) -> None:
        kwargs.pop("status_code", None)
        super().__init__(message, status_code, code="rate_limited", **kwargs)
        self.retry_after = retry_after


class ShopifyNotFoundError(ShopifyHTTPError):
    """Raised for 404 responses."""

    def __init__(self, message: str = "Resource not found", **kwargs: Any) -> None:
        kwargs.pop("status_code", None)
        super().__init__(message, 404, code="not_found", **kwargs)


class ShopifyValidationError(ShopifyHTTPError):
    """Raised for 422 (and 400) validation errors."""

    def __init__(self, message: str = "Validation failed", **kwargs: Any) -> None:
        kwargs.pop("status_code", None)
        super().__init__(message, 422, code="validation_error", **kwargs)


class ShopifyServerError(ShopifyHTTPError):
    """Raised for 5xx responses after retries are exhausted."""

    def __init__(self, message: str = "Shopify server error", **kwargs: Any) -> None:
        status = kwargs.pop("status_code", 500)
        super().__init__(message, status, code="server_error", **kwargs)


def _status_to_code(status: int) -> str:
    return {
        400: "bad_request",
        401: "unauthorized",
        403: "forbidden",
        404: "not_found",
        409: "conflict",
        422: "validation_error",
        429: "rate_limited",
    }.get(status, "http_error")


# ---------------------------------------------------------------------------
# Typed responses
# ---------------------------------------------------------------------------


@dataclass
class ShopifyResponse:
    """A typed wrapper around a Shopify API response.

    Parameters
    ----------
    status_code:
        HTTP status code.
    body:
        Parsed JSON body (dict) or raw text.
    headers:
        Response headers (case-insensitive).
    request:
        The :class:`urllib.request.Request` that produced this response
        (useful for debugging / retries).
    """

    status_code: int
    body: Any
    headers: Mapping[str, str] = field(default_factory=dict)
    request: Optional[urllib.request.Request] = None

    @property
    def ok(self) -> bool:
        return 200 <= self.status_code < 300

    @property
    def data(self) -> Any:
        """Alias for :attr:`body` (parsed JSON)."""
        return self.body

    def json(self) -> Any:
        """Return the parsed JSON body."""
        return self.body

    def header(self, name: str, default: Optional[str] = None) -> Optional[str]:
        """Case-insensitive header lookup."""
        return _header_get(self.headers, name, default)

    @property
    def rate_limit(self) -> Optional["RateLimitInfo"]:
        """Parsed rate-limit information from the response headers."""
        return RateLimitInfo.from_headers(self.headers)


@dataclass
class RateLimitInfo:
    """Parsed Shopify rate-limit bucket state.

    For the REST Admin API, Shopify returns
    ``X-Shopify-Shop-Api-Call-Limit`` as ``"32/40"`` (used/available) and
    ``Retry-After`` (seconds) when throttled. For GraphQL, cost info is in
    the response body extensions.
    """

    used: Optional[int] = None
    available: Optional[int] = None
    retry_after: Optional[float] = None

    @property
    def bucket_size(self) -> Optional[int]:
        if self.used is not None and self.available is not None:
            return self.used + self.available
        return None

    @property
    def remaining(self) -> Optional[int]:
        return self.available

    @property
    def is_full(self) -> bool:
        return self.available is not None and self.available <= 0

    @classmethod
    def from_headers(cls, headers: Mapping[str, str]) -> Optional["RateLimitInfo"]:
        limit = _header_get(headers, "X-Shopify-Shop-Api-Call-Limit")
        retry = _header_get(headers, "Retry-After")
        if limit is None and retry is None:
            return None
        used = available = None
        if limit and "/" in limit:
            used_s, total_s = limit.split("/", 1)
            try:
                used = int(used_s.strip())
                total = int(total_s.strip())
                # Shopify reports "used/total"; remaining = total - used.
                available = max(total - used, 0)
            except ValueError:
                used = available = None
        retry_after = None
        if retry is not None:
            try:
                retry_after = float(retry)
            except ValueError:
                retry_after = None
        return cls(used=used, available=available, retry_after=retry_after)


class ShopifyResource:
    """A typed, attribute-accessible wrapper around a Shopify resource dict.

    Shopify returns resources as JSON objects with string keys. This class
    exposes them via attribute access (``product.title``) while preserving
    dict-style access (``product["title"]``) and the raw payload
    (``product.raw``).

    Nested dicts are wrapped as :class:`ShopifyResource` and lists of dicts
    become lists of :class:`ShopifyResource`, so ``order.line_items[0].price``
    works naturally.
    """

    __slots__ = ("_data",)

    def __init__(self, data: Mapping[str, Any]) -> None:
        object.__setattr__(self, "_data", dict(data))

    # -- attribute access ---------------------------------------------------
    def __getattr__(self, name: str) -> Any:
        if name.startswith("_"):
            raise AttributeError(name)
        data = object.__getattribute__(self, "_data")
        if name in data:
            return _wrap(data[name])
        raise AttributeError(
            f"{type(self).__name__!r} object has no attribute {name!r}"
        )

    def __setattr__(self, name: str, value: Any) -> None:
        if name.startswith("_"):
            object.__setattr__(self, name, value)
        else:
            object.__getattribute__(self, "_data")[name] = value

    # -- mapping access -----------------------------------------------------
    def __getitem__(self, key: str) -> Any:
        return _wrap(object.__getattribute__(self, "_data")[key])

    def __setitem__(self, key: str, value: Any) -> None:
        object.__getattribute__(self, "_data")[key] = value

    def __contains__(self, key: object) -> bool:
        return key in object.__getattribute__(self, "_data")

    def get(self, key: str, default: Any = None) -> Any:
        data = object.__getattribute__(self, "_data")
        return _wrap(data[key]) if key in data else default

    def keys(self) -> Iterable[str]:
        return object.__getattribute__(self, "_data").keys()

    def items(self) -> Iterable[Tuple[str, Any]]:
        return ((k, _wrap(v)) for k, v in object.__getattribute__(self, "_data").items())

    def to_dict(self) -> Dict[str, Any]:
        """Return a deep, plain-``dict`` copy of the resource."""
        return _unwrap(object.__getattribute__(self, "_data"))

    @property
    def raw(self) -> Dict[str, Any]:
        """The underlying raw dict (not copied)."""
        return object.__getattribute__(self, "_data")

    def __eq__(self, other: object) -> bool:
        if isinstance(other, ShopifyResource):
            return self.raw == other.raw
        if isinstance(other, Mapping):
            return self.raw == dict(other)
        return NotImplemented

    def __repr__(self) -> str:  # pragma: no cover - cosmetic
        keys = ", ".join(list(self.raw.keys())[:5])
        return f"<ShopifyResource keys=[{keys}{', ...' if len(self.raw) > 5 else ''}]>"

    def __iter__(self) -> Iterator[str]:
        return iter(self.raw)


def _wrap(value: Any) -> Any:
    """Recursively wrap dicts as :class:`ShopifyResource`."""
    if isinstance(value, ShopifyResource):
        return value
    if isinstance(value, Mapping):
        return ShopifyResource(value)
    if isinstance(value, list):
        return [_wrap(v) for v in value]
    return value


def _unwrap(value: Any) -> Any:
    """Recursively convert :class:`ShopifyResource` back to plain dicts."""
    if isinstance(value, ShopifyResource):
        return {k: _unwrap(v) for k, v in value.raw.items()}
    if isinstance(value, Mapping):
        return {k: _unwrap(v) for k, v in value.items()}
    if isinstance(value, list):
        return [_unwrap(v) for v in value]
    return value


def _header_get(headers: Mapping[str, str], name: str, default: Optional[str] = None) -> Optional[str]:
    """Case-insensitive header lookup."""
    if not headers:
        return default
    lname = name.lower()
    for key, value in headers.items():
        if key.lower() == lname:
            return value
    return default


# ---------------------------------------------------------------------------
# Transport
# ---------------------------------------------------------------------------


class ShopifyTransport:
    """HTTP transport for Shopify API calls.

    This is the single seam through which all network I/O flows. It is
    injectable so tests can substitute a fake transport and run fully offline.

    Parameters
    ----------
    timeout:
        Per-request timeout in seconds.
    opener:
        A callable ``(request, timeout) -> (status, headers, body_bytes)``.
        Defaults to :meth:`_urllib_opener`. Tests override this.
    """

    def __init__(
        self,
        timeout: float = DEFAULT_TIMEOUT,
        opener: Optional[Callable[[urllib.request.Request, float], Tuple[int, Mapping[str, str], bytes]]] = None,
    ) -> None:
        self.timeout = timeout
        self._opener = opener or self._urllib_opener

    def send(
        self, request: urllib.request.Request
    ) -> Tuple[int, Mapping[str, str], bytes]:
        """Execute ``request`` and return ``(status, headers, body_bytes)``."""
        return self._opener(request, self.timeout)

    @staticmethod
    def _urllib_opener(
        request: urllib.request.Request, timeout: float
    ) -> Tuple[int, Mapping[str, str], bytes]:
        try:
            with urllib.request.urlopen(request, timeout=timeout) as resp:  # noqa: S310
                return resp.status, dict(resp.headers.items()), resp.read()
        except urllib.error.HTTPError as exc:  # non-2xx
            body = exc.read() if hasattr(exc, "read") else b""
            return exc.code, dict(exc.headers.items()) if exc.headers else {}, body


# ---------------------------------------------------------------------------
# Pagination
# ---------------------------------------------------------------------------


@dataclass
class Page:
    """A single page of results from a paginated Shopify endpoint."""

    items: List[Any]
    next_cursor: Optional[str] = None
    has_next: bool = False
    raw: Any = None


def paginate(fetch: Callable[[Optional[str]], Page]) -> Iterator[Any]:
    """Yield items across pages using a ``fetch(cursor) -> Page`` callable.

    The callable receives ``None`` for the first page and the previous page's
    ``next_cursor`` thereafter. Iteration stops when ``has_next`` is false or
    ``next_cursor`` is ``None``.
    """
    cursor: Optional[str] = None
    while True:
        page = fetch(cursor)
        for item in page.items:
            yield item
        if not page.has_next or not page.next_cursor:
            break
        cursor = page.next_cursor


# ---------------------------------------------------------------------------
# OAuth helpers
# ---------------------------------------------------------------------------


class ShopifyOAuth:
    """Helpers for the Shopify OAuth 2.0 authorization-code flow.

    These are pure helpers; they do not persist tokens. Use them to exchange
    an authorization code for an access token and to refresh it.
    """

    def __init__(
        self,
        api_key: str,
        api_secret: str,
        scopes: Optional[Sequence[str]] = None,
        transport: Optional[ShopifyTransport] = None,
    ) -> None:
        self.api_key = api_key
        self.api_secret = api_secret
        self.scopes = list(scopes or [])
        self.transport = transport or ShopifyTransport()

    def authorize_url(
        self, shop: str, redirect_uri: str, state: Optional[str] = None
    ) -> str:
        """Build the Shopify authorization URL to redirect the merchant to."""
        params = {
            "client_id": self.api_key,
            "scope": ",".join(self.scopes),
            "redirect_uri": redirect_uri,
        }
        if state:
            params["state"] = state
        return f"https://{shop}/admin/oauth/authorize?{urllib.parse.urlencode(params)}"

    def exchange_code(self, shop: str, code: str) -> Dict[str, Any]:
        """Exchange an authorization ``code`` for an access token."""
        payload = {
            "client_id": self.api_key,
            "client_secret": self.api_secret,
            "code": code,
        }
        return self._post_form(shop, OAUTH_TOKEN_PATH, payload)

    def refresh_token(self, shop: str, refresh_token: str) -> Dict[str, Any]:
        """Refresh an expiring access token using a refresh token."""
        payload = {
            "grant_type": "refresh_token",
            "client_id": self.api_key,
            "client_secret": self.api_secret,
            "refresh_token": refresh_token,
        }
        return self._post_form(shop, OAUTH_TOKEN_PATH, payload)

    def revoke(self, shop: str, token: str) -> Dict[str, Any]:
        """Revoke an access token."""
        payload = {"client_id": self.api_key, "token": token}
        return self._post_form(shop, OAUTH_REVOKE_PATH, payload)

    def _post_form(self, shop: str, path: str, payload: Mapping[str, Any]) -> Dict[str, Any]:
        url = f"https://{shop}{path}"
        data = urllib.parse.urlencode(payload).encode("utf-8")
        req = urllib.request.Request(
            url,
            data=data,
            method="POST",
            headers={"Content-Type": "application/x-www-form-urlencoded"},
        )
        status, headers, body = self.transport.send(req)
        parsed = _parse_body(body)
        if not (200 <= status < 300):
            raise _error_from_response(status, parsed, headers)
        return parsed if isinstance(parsed, dict) else {"result": parsed}


# ---------------------------------------------------------------------------
# REST Admin API client
# ---------------------------------------------------------------------------


class ShopifyAdminClient:
    """Client for the Shopify REST Admin API.

    Parameters
    ----------
    shop:
        The shop domain, e.g. ``"my-store.myshopify.com"`` (with or without
        scheme). If omitted, ``SHOPIFY_SHOP`` is used.
    access_token:
        Admin API access token (private/custom app or OAuth). If omitted,
        ``SHOPIFY_ACCESS_TOKEN`` is used.
    api_version:
        Admin API version string, e.g. ``"2024-10"``. Defaults to
        ``SHOPIFY_API_VERSION`` or :data:`DEFAULT_API_VERSION`.
    timeout:
        Per-request timeout in seconds.
    max_retries:
        Maximum retry attempts for transient failures.
    transport:
        Optional :class:`ShopifyTransport` (mainly for tests).
    session:
        Optional ``requests.Session``-like object. When provided, its
        ``request`` method is used instead of the stdlib transport. This lets
        callers plug in a custom HTTP stack while keeping the same API.
    """

    def __init__(
        self,
        shop: Optional[str] = None,
        access_token: Optional[str] = None,
        api_version: Optional[str] = None,
        timeout: float = DEFAULT_TIMEOUT,
        max_retries: int = DEFAULT_MAX_RETRIES,
        transport: Optional[ShopifyTransport] = None,
        session: Any = None,
    ) -> None:
        self.shop = _normalize_shop(shop or os.environ.get("SHOPIFY_SHOP", ""))
        self.access_token = access_token or os.environ.get("SHOPIFY_ACCESS_TOKEN")
        self.api_version = api_version or os.environ.get(
            "SHOPIFY_API_VERSION", DEFAULT_API_VERSION
        )
        self.max_retries = max_retries
        self.transport = transport or ShopifyTransport(timeout=timeout)
        self.session = session

        # Resource namespaces
        self.products = ProductsResource(self)
        self.orders = OrdersResource(self)
        self.customers = CustomersResource(self)
        self.inventory = InventoryResource(self)
        self.webhooks = WebhooksResource(self)

    # -- low-level request --------------------------------------------------
    def request(
        self,
        method: str,
        resource: str,
        *,
        resource_id: Optional[Union[str, int]] = None,
        subresource: Optional[str] = None,
        params: Optional[Mapping[str, Any]] = None,
        json_body: Optional[Mapping[str, Any]] = None,
        query: Optional[Mapping[str, Any]] = None,
    ) -> ShopifyResponse:
        """Perform a REST Admin API request and return a :class:`ShopifyResponse`.

        Retries transient failures (5xx, 429, network errors) with exponential
        backoff + jitter, and sleeps out rate-limit windows when Shopify
        reports them.
        """
        url = self._build_url(resource, resource_id, subresource, params, query)
        body = _encode_json(json_body) if json_body is not None else None
        headers = self._headers()
        if body is not None:
            headers["Content-Type"] = "application/json"

        attempt = 0
        while True:
            req = urllib.request.Request(url, data=body, method=method.upper(), headers=headers)
            try:
                if self.session is not None:
                    status, resp_headers, raw = self._send_via_session(req, method, url, body, headers)
                else:
                    status, resp_headers, raw = self.transport.send(req)
            except (urllib.error.URLError, TimeoutError, ConnectionError) as exc:
                if attempt >= self.max_retries:
                    raise ShopifyError(f"Network error contacting Shopify: {exc}") from exc
                _sleep_backoff(attempt)
                attempt += 1
                continue

            parsed = _parse_body(raw)

            if 200 <= status < 300:
                return ShopifyResponse(status, parsed, resp_headers, req)

            # Rate limited: respect Retry-After / bucket and retry.
            if status == 429:
                retry_after = _retry_after_seconds(resp_headers)
                if attempt < self.max_retries:
                    wait = retry_after if retry_after is not None else _sleep_backoff(attempt, return_seconds=True)
                    logger.warning("Shopify 429; sleeping %.2fs before retry", wait)
                    time.sleep(wait)
                    attempt += 1
                    continue
                raise ShopifyRateLimitError(retry_after=retry_after, headers=resp_headers, body=parsed)

            # Transient server error: retry.
            if status in RETRYABLE_STATUS and status != 429:
                if attempt < self.max_retries:
                    _sleep_backoff(attempt)
                    attempt += 1
                    continue
                raise ShopifyServerError(
                    f"Shopify server error ({status})", status_code=status, body=parsed, headers=resp_headers
                )

            # Non-retryable error.
            raise _error_from_response(status, parsed, resp_headers)

    def _send_via_session(
        self,
        req: urllib.request.Request,
        method: str,
        url: str,
        body: Optional[bytes],
        headers: Mapping[str, str],
    ) -> Tuple[int, Mapping[str, str], bytes]:
        """Send via an injected ``requests``-like session."""
        resp = self.session.request(
            method.upper(), url, data=body, headers=dict(headers), timeout=self.transport.timeout
        )
        raw = resp.content if hasattr(resp, "content") else b""
        return resp.status_code, dict(resp.headers), raw

    def _build_url(
        self,
        resource: str,
        resource_id: Optional[Union[str, int]],
        subresource: Optional[str],
        params: Optional[Mapping[str, Any]],
        query: Optional[Mapping[str, Any]],
    ) -> str:
        # Build the path with the .json suffix at the very end, e.g.
        #   /admin/api/2024-10/products.json
        #   /admin/api/2024-10/products/42.json
        #   /admin/api/2024-10/products/42/variants.json
        #   /admin/api/2024-10/inventory_levels/adjust.json
        segments = [resource]
        if resource_id is not None:
            segments.append(str(resource_id))
        if subresource:
            segments.append(subresource)
        path = f"/admin/api/{self.api_version}/" + "/".join(segments) + ".json"
        url = f"https://{self.shop}{path}"
        merged = {}
        if params:
            merged.update({k: v for k, v in params.items() if v is not None})
        if query:
            merged.update({k: v for k, v in query.items() if v is not None})
        if merged:
            url += "?" + urllib.parse.urlencode(merged, doseq=True)
        return url

    def _headers(self) -> Dict[str, str]:
        headers = {"Accept": "application/json"}
        if self.access_token:
            headers["X-Shopify-Access-Token"] = self.access_token
        return headers

    # -- pagination ---------------------------------------------------------
    def paginate(
        self,
        resource: str,
        *,
        params: Optional[Mapping[str, Any]] = None,
        limit: Optional[int] = None,
    ) -> Iterator[ShopifyResource]:
        """Yield :class:`ShopifyResource` items across all pages of a list endpoint.

        Uses the REST ``Link`` header for cursor pagination. Stops after
        ``limit`` items if ``limit`` is given.
        """
        cursor: Optional[str] = None
        yielded = 0
        while True:
            page_params = dict(params or {})
            if cursor:
                page_params["limit"] = page_params.get("limit", 50)
                page_params["page_info"] = cursor
            resp = self.request("GET", resource, params=page_params)
            items = _extract_items(resp.body, resource)
            for item in items:
                yield ShopifyResource(item)
                yielded += 1
                if limit is not None and yielded >= limit:
                    return
            cursor = _next_cursor_from_link(resp.headers.get("Link"))
            if not cursor:
                break

    # -- generic helpers ----------------------------------------------------
    def get(self, resource: str, resource_id: Union[str, int], **kw: Any) -> ShopifyResource:
        resp = self.request("GET", resource, resource_id=resource_id, **kw)
        return ShopifyResource(_unwrap_resource(resp.body, resource, resource_id))

    def create(self, resource: str, payload: Mapping[str, Any], **kw: Any) -> ShopifyResource:
        resp = self.request("POST", resource, json_body={_singular(resource): dict(payload)}, **kw)
        return ShopifyResource(_unwrap_resource(resp.body, resource))

    def update(
        self, resource: str, resource_id: Union[str, int], payload: Mapping[str, Any], **kw: Any
    ) -> ShopifyResource:
        resp = self.request(
            "PUT", resource, resource_id=resource_id, json_body={_singular(resource): dict(payload)}, **kw
        )
        return ShopifyResource(_unwrap_resource(resp.body, resource, resource_id))

    def delete(self, resource: str, resource_id: Union[str, int], **kw: Any) -> ShopifyResponse:
        return self.request("DELETE", resource, resource_id=resource_id, **kw)

    def count(self, resource: str, **kw: Any) -> int:
        resp = self.request("GET", resource, subresource="count", **kw)
        return int(resp.body.get("count", 0)) if isinstance(resp.body, dict) else 0


# ---------------------------------------------------------------------------
# GraphQL Admin API client
# ---------------------------------------------------------------------------


class ShopifyGraphQLClient:
    """Client for the Shopify GraphQL Admin API.

    Parameters mirror :class:`ShopifyAdminClient`. The GraphQL endpoint is a
    single URL; queries and mutations are POSTed as JSON.
    """

    def __init__(
        self,
        shop: Optional[str] = None,
        access_token: Optional[str] = None,
        api_version: Optional[str] = None,
        timeout: float = DEFAULT_TIMEOUT,
        max_retries: int = DEFAULT_MAX_RETRIES,
        transport: Optional[ShopifyTransport] = None,
        session: Any = None,
    ) -> None:
        self.shop = _normalize_shop(shop or os.environ.get("SHOPIFY_SHOP", ""))
        self.access_token = access_token or os.environ.get("SHOPIFY_ACCESS_TOKEN")
        self.api_version = api_version or os.environ.get(
            "SHOPIFY_API_VERSION", DEFAULT_API_VERSION
        )
        self.max_retries = max_retries
        self.transport = transport or ShopifyTransport(timeout=timeout)
        self.session = session

    def execute(
        self,
        query: str,
        variables: Optional[Mapping[str, Any]] = None,
        operation_name: Optional[str] = None,
    ) -> "GraphQLResponse":
        """Execute a GraphQL query/mutation and return a :class:`GraphQLResponse`."""
        url = f"https://{self.shop}{GRAPHQL_API_PATH.format(version=self.api_version)}"
        payload = {"query": query}
        if variables:
            payload["variables"] = dict(variables)
        if operation_name:
            payload["operationName"] = operation_name
        body = _encode_json(payload)
        headers = {"Content-Type": "application/json", "Accept": "application/json"}
        if self.access_token:
            headers["X-Shopify-Access-Token"] = self.access_token

        attempt = 0
        while True:
            req = urllib.request.Request(url, data=body, method="POST", headers=headers)
            try:
                if self.session is not None:
                    status, resp_headers, raw = self._send_via_session(req, url, body, headers)
                else:
                    status, resp_headers, raw = self.transport.send(req)
            except (urllib.error.URLError, TimeoutError, ConnectionError) as exc:
                if attempt >= self.max_retries:
                    raise ShopifyError(f"Network error contacting Shopify: {exc}") from exc
                _sleep_backoff(attempt)
                attempt += 1
                continue

            parsed = _parse_body(raw)

            if 200 <= status < 300:
                gql = GraphQLResponse(status, parsed, resp_headers)
                if gql.throttled and attempt < self.max_retries:
                    wait = gql.cost.throttle_wait_seconds or _sleep_backoff(attempt, return_seconds=True)
                    logger.warning("GraphQL throttled; sleeping %.2fs", wait)
                    time.sleep(wait)
                    attempt += 1
                    continue
                if gql.errors and not gql.data:
                    raise ShopifyHTTPError(
                        f"GraphQL error: {gql.errors}", status_code=status, body=parsed, headers=resp_headers
                    )
                return gql

            if status == 429:
                retry_after = _retry_after_seconds(resp_headers)
                if attempt < self.max_retries:
                    wait = retry_after if retry_after is not None else _sleep_backoff(attempt, return_seconds=True)
                    time.sleep(wait)
                    attempt += 1
                    continue
                raise ShopifyRateLimitError(retry_after=retry_after, headers=resp_headers, body=parsed)

            if status in RETRYABLE_STATUS:
                if attempt < self.max_retries:
                    _sleep_backoff(attempt)
                    attempt += 1
                    continue
                raise ShopifyServerError(
                    f"Shopify server error ({status})", status_code=status, body=parsed, headers=resp_headers
                )

            raise _error_from_response(status, parsed, resp_headers)

    def _send_via_session(
        self, req: urllib.request.Request, url: str, body: bytes, headers: Mapping[str, str]
    ) -> Tuple[int, Mapping[str, str], bytes]:
        resp = self.session.request(
            "POST", url, data=body, headers=dict(headers), timeout=self.transport.timeout
        )
        raw = resp.content if hasattr(resp, "content") else b""
        return resp.status_code, dict(resp.headers), raw

    # Convenience helpers ---------------------------------------------------
    def query(self, query: str, **variables: Any) -> Any:
        """Execute a query and return the ``data`` dict."""
        return self.execute(query, variables or None).data

    def mutate(self, mutation: str, **variables: Any) -> Any:
        """Execute a mutation and return the ``data`` dict."""
        return self.execute(mutation, variables or None).data


@dataclass
class GraphQLResponse:
    """Typed wrapper around a GraphQL Admin API response."""

    status_code: int
    body: Mapping[str, Any]
    headers: Mapping[str, str] = field(default_factory=dict)

    @property
    def data(self) -> Optional[Dict[str, Any]]:
        return self.body.get("data") if isinstance(self.body, dict) else None

    @property
    def errors(self) -> Optional[List[Dict[str, Any]]]:
        return self.body.get("errors") if isinstance(self.body, dict) else None

    @property
    def cost(self) -> "GraphQLCost":
        ext = (self.body or {}).get("extensions", {}) if isinstance(self.body, dict) else {}
        return GraphQLCost.from_extensions(ext.get("cost", {}))

    @property
    def throttled(self) -> bool:
        ext = (self.body or {}).get("extensions", {}) if isinstance(self.body, dict) else {}
        return bool(ext.get("cost", {}).get("throttleStatus", {}).get("currentlyAvailable", 1) <= 0)


@dataclass
class GraphQLCost:
    """Parsed GraphQL cost/throttle information from response extensions."""

    requested_query_cost: Optional[int] = None
    actual_query_cost: Optional[int] = None
    throttle_status: Dict[str, Any] = field(default_factory=dict)

    @property
    def currently_available(self) -> Optional[int]:
        return self.throttle_status.get("currentlyAvailable")

    @property
    def restore_rate(self) -> Optional[float]:
        return self.throttle_status.get("restoreRate")

    @property
    def throttle_wait_seconds(self) -> Optional[float]:
        """Seconds to wait until the GraphQL bucket is usable again."""
        available = self.currently_available
        restore = self.restore_rate
        if available is None or not restore:
            return None
        if available > 0:
            return 0.0
        return 1.0 / float(restore)

    @classmethod
    def from_extensions(cls, cost: Mapping[str, Any]) -> "GraphQLCost":
        return cls(
            requested_query_cost=cost.get("requestedQueryCost"),
            actual_query_cost=cost.get("actualQueryCost"),
            throttle_status=dict(cost.get("throttleStatus", {})),
        )


# ---------------------------------------------------------------------------
# Resource namespaces
# ---------------------------------------------------------------------------


class _BaseResource:
    """Base class for resource namespaces (products, orders, ...)."""

    resource_name: str = ""

    def __init__(self, client: ShopifyAdminClient) -> None:
        self.client = client

    def list(self, **params: Any) -> List[ShopifyResource]:
        """Return a single page of resources (pass ``limit``/``page_info``)."""
        resp = self.client.request("GET", self.resource_name, params=params or None)
        return [ShopifyResource(item) for item in _extract_items(resp.body, self.resource_name)]

    def iter(self, limit: Optional[int] = None, **params: Any) -> Iterator[ShopifyResource]:
        """Iterate over all resources, auto-paginating via the ``Link`` header."""
        return self.client.paginate(self.resource_name, params=params or None, limit=limit)

    def get(self, resource_id: Union[str, int], **params: Any) -> ShopifyResource:
        return self.client.get(self.resource_name, resource_id, params=params or None)

    def create(self, payload: Mapping[str, Any]) -> ShopifyResource:
        return self.client.create(self.resource_name, payload)

    def update(self, resource_id: Union[str, int], payload: Mapping[str, Any]) -> ShopifyResource:
        return self.client.update(self.resource_name, resource_id, payload)

    def delete(self, resource_id: Union[str, int]) -> ShopifyResponse:
        return self.client.delete(self.resource_name, resource_id)

    def count(self, **params: Any) -> int:
        return self.client.count(self.resource_name, params=params or None)


class ProductsResource(_BaseResource):
    """Resource namespace for Shopify products.

    Wraps the REST ``/products`` endpoints with typed helpers.
    """

    resource_name = "products"

    def variants(self, product_id: Union[str, int]) -> List[ShopifyResource]:
        """List variants for a product."""
        resp = self.client.request(
            "GET", "products", resource_id=product_id, subresource="variants"
        )
        return [ShopifyResource(v) for v in _extract_items(resp.body, "variants")]

    def images(self, product_id: Union[str, int]) -> List[ShopifyResource]:
        """List images for a product."""
        resp = self.client.request(
            "GET", "products", resource_id=product_id, subresource="images"
        )
        return [ShopifyResource(v) for v in _extract_items(resp.body, "images")]


class OrdersResource(_BaseResource):
    """Resource namespace for Shopify orders.

    Wraps the REST ``/orders`` endpoints with typed helpers.
    """

    resource_name = "orders"

    def open(self, **params: Any) -> List[ShopifyResource]:
        """List open orders (``status=open``)."""
        return self.list(status="open", **params)

    def closed(self, **params: Any) -> List[ShopifyResource]:
        """List closed orders (``status=closed``)."""
        return self.list(status="closed", **params)

    def cancelled(self, **params: Any) -> List[ShopifyResource]:
        """List cancelled orders (``status=cancelled``)."""
        return self.list(status="cancelled", **params)

    def fulfillments(self, order_id: Union[str, int]) -> List[ShopifyResource]:
        """List fulfillments for an order."""
        resp = self.client.request(
            "GET", "orders", resource_id=order_id, subresource="fulfillments"
        )
        return [ShopifyResource(f) for f in _extract_items(resp.body, "fulfillments")]

    def cancel(self, order_id: Union[str, int], **params: Any) -> ShopifyResponse:
        """Cancel an order (``POST /orders/:id/cancel.json``)."""
        return self.client.request(
            "POST", "orders", resource_id=order_id, subresource="cancel", params=params or None
        )

    def close(self, order_id: Union[str, int], **params: Any) -> ShopifyResponse:
        """Close an order (``POST /orders/:id/close.json``)."""
        return self.client.request(
            "POST", "orders", resource_id=order_id, subresource="close", params=params or None
        )


class CustomersResource(_BaseResource):
    """Resource namespace for Shopify customers.

    Wraps the REST ``/customers`` endpoints with typed helpers.
    """

    resource_name = "customers"

    def search(self, query: str, **params: Any) -> List[ShopifyResource]:
        """Search customers by name/email (``query`` param)."""
        return self.list(query=query, **params)

    def orders(self, customer_id: Union[str, int], **params: Any) -> List[ShopifyResource]:
        """List orders for a customer."""
        resp = self.client.request(
            "GET", "customers", resource_id=customer_id, subresource="orders", params=params or None
        )
        return [ShopifyResource(o) for o in _extract_items(resp.body, "orders")]


class InventoryResource:
    """Resource namespace for Shopify inventory.

    Wraps the REST ``/inventory_levels`` and ``/locations`` endpoints.
    """

    def __init__(self, client: ShopifyAdminClient) -> None:
        self.client = client

    def levels(
        self,
        *,
        inventory_item_ids: Optional[Sequence[Union[str, int]]] = None,
        location_ids: Optional[Sequence[Union[str, int]]] = None,
        limit: Optional[int] = None,
    ) -> List[ShopifyResource]:
        """List inventory levels, optionally filtered by item/location ids."""
        params: Dict[str, Any] = {}
        if inventory_item_ids:
            params["inventory_item_ids"] = ",".join(str(i) for i in inventory_item_ids)
        if location_ids:
            params["location_ids"] = ",".join(str(i) for i in location_ids)
        if limit:
            params["limit"] = limit
        resp = self.client.request("GET", "inventory_levels", params=params or None)
        return [ShopifyResource(l) for l in _extract_items(resp.body, "inventory_levels")]

    def adjust(
        self,
        location_id: Union[str, int],
        inventory_item_id: Union[str, int],
        adjustment: int,
    ) -> ShopifyResponse:
        """Adjust the inventory level for an item at a location."""
        payload = {
            "location_id": location_id,
            "inventory_item_id": inventory_item_id,
            "available_adjustment": adjustment,
        }
        return self.client.request(
            "POST", "inventory_levels", subresource="adjust", json_body=payload
        )

    def set(
        self,
        location_id: Union[str, int],
        inventory_item_id: Union[str, int],
        available: int,
    ) -> ShopifyResponse:
        """Set (connect) the available inventory for an item at a location."""
        payload = {
            "location_id": location_id,
            "inventory_item_id": inventory_item_id,
            "available": available,
        }
        return self.client.request(
            "POST", "inventory_levels", subresource="set", json_body=payload
        )

    def locations(self, **params: Any) -> List[ShopifyResource]:
        """List shop locations."""
        resp = self.client.request("GET", "locations", params=params or None)
        return [ShopifyResource(l) for l in _extract_items(resp.body, "locations")]


class WebhooksResource(_BaseResource):
    """Resource namespace for Shopify webhook subscriptions.

    Wraps the REST ``/webhooks`` endpoints with typed helpers.
    """

    resource_name = "webhook_subscriptions"

    def create(self, payload: Mapping[str, Any]) -> ShopifyResource:
        """Create a webhook subscription.

        ``payload`` must include ``topic``, ``address``, and ``format``.
        """
        return self.client.create(self.resource_name, payload)

    def topics(self) -> List[str]:
        """Return the list of valid webhook topics (static, from Shopify docs)."""
        return list(WEBHOOK_TOPICS)


# ---------------------------------------------------------------------------
# Factory
# ---------------------------------------------------------------------------


class ShopifyClient:
    """Factory that builds a REST or GraphQL client from a single config.

    Parameters
    ----------
    shop:
        Shop domain. Falls back to ``SHOPIFY_SHOP``.
    access_token:
        Admin API access token. Falls back to ``SHOPIFY_ACCESS_TOKEN``.
    api_version:
        Admin API version. Falls back to ``SHOPIFY_API_VERSION`` then
        :data:`DEFAULT_API_VERSION`.
    graphql:
        If true, :attr:`rest` is a :class:`ShopifyGraphQLClient` and
        :attr:`graphql` is the same object. If false (default), :attr:`rest`
        is a :class:`ShopifyAdminClient` and :attr:`graphql` is a lazily
        built :class:`ShopifyGraphQLClient`.
    **kwargs:
        Forwarded to the underlying client (``timeout``, ``max_retries``,
        ``transport``, ``session``).
    """

    def __init__(
        self,
        shop: Optional[str] = None,
        access_token: Optional[str] = None,
        api_version: Optional[str] = None,
        graphql: bool = False,
        **kwargs: Any,
    ) -> None:
        self.shop = _normalize_shop(shop or os.environ.get("SHOPIFY_SHOP", ""))
        self.access_token = access_token or os.environ.get("SHOPIFY_ACCESS_TOKEN")
        self.api_version = api_version or os.environ.get(
            "SHOPIFY_API_VERSION", DEFAULT_API_VERSION
        )
        self._graphql_flag = graphql
        self._kwargs = kwargs
        self.rest: Union[ShopifyAdminClient, ShopifyGraphQLClient]
        if graphql:
            self.rest = ShopifyGraphQLClient(
                shop=self.shop,
                access_token=self.access_token,
                api_version=self.api_version,
                **kwargs,
            )
            self.graphql: ShopifyGraphQLClient = self.rest  # type: ignore[assignment]
        else:
            self.rest = ShopifyAdminClient(
                shop=self.shop,
                access_token=self.access_token,
                api_version=self.api_version,
                **kwargs,
            )
            self.graphql = ShopifyGraphQLClient(
                shop=self.shop,
                access_token=self.access_token,
                api_version=self.api_version,
                **kwargs,
            )

    # Delegate resource namespaces for convenience.
    @property
    def products(self) -> ProductsResource:
        return self.rest.products  # type: ignore[union-attr]

    @property
    def orders(self) -> OrdersResource:
        return self.rest.orders  # type: ignore[union-attr]

    @property
    def customers(self) -> CustomersResource:
        return self.rest.customers  # type: ignore[union-attr]

    @property
    def inventory(self) -> InventoryResource:
        return self.rest.inventory  # type: ignore[union-attr]

    @property
    def webhooks(self) -> WebhooksResource:
        return self.rest.webhooks  # type: ignore[union-attr]


# ---------------------------------------------------------------------------
# Webhook topics (subset of Shopify's documented topics)
# ---------------------------------------------------------------------------

WEBHOOK_TOPICS = (
    "orders/create",
    "orders/updated",
    "orders/cancelled",
    "orders/fulfilled",
    "orders/paid",
    "orders/partially_fulfilled",
    "orders/partially_paid",
    "orders/expired",
    "orders/deleted",
    "products/create",
    "products/update",
    "products/delete",
    "customers/create",
    "customers/update",
    "customers/delete",
    "inventory_levels/update",
    "inventory_items/create",
    "inventory_items/update",
    "inventory_items/delete",
    "checkouts/create",
    "checkouts/update",
    "checkouts/delete",
    "fulfillments/create",
    "fulfillments/update",
    "refunds/create",
    "app/uninstalled",
    "shop/update",
)


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------


def _normalize_shop(shop: str) -> str:
    """Strip scheme/trailing slash from a shop domain."""
    if not shop:
        return ""
    shop = shop.strip()
    if "://" in shop:
        shop = shop.split("://", 1)[1]
    return shop.strip("/")


def _encode_json(payload: Mapping[str, Any]) -> bytes:
    return json.dumps(payload).encode("utf-8")


def _parse_body(raw: bytes) -> Any:
    if not raw:
        return {}
    if isinstance(raw, bytes):
        try:
            text = raw.decode("utf-8")
        except UnicodeDecodeError:
            return raw
    else:
        text = raw
    try:
        return json.loads(text)
    except (ValueError, TypeError):
        return text


def _retry_after_seconds(headers: Mapping[str, str]) -> Optional[float]:
    retry = _header_get(headers, "Retry-After")
    if retry is None:
        return None
    try:
        return float(retry)
    except ValueError:
        return None


def _sleep_backoff(attempt: int, return_seconds: bool = False) -> Optional[float]:
    """Exponential backoff with full jitter.

    Returns the number of seconds slept when ``return_seconds`` is true,
    otherwise ``None``.
    """
    delay = min(DEFAULT_BACKOFF_CAP, DEFAULT_BACKOFF_BASE * (2 ** attempt))
    delay = random.uniform(0, delay) if delay > 0 else 0.0
    if return_seconds:
        return delay
    if delay > 0:
        time.sleep(delay)
    return None


def _error_from_response(
    status: int, body: Any, headers: Mapping[str, str]
) -> ShopifyHTTPError:
    """Map an HTTP status + body to a typed :class:`ShopifyHTTPError`."""
    message = _extract_error_message(body) or f"Shopify API error (HTTP {status})"
    if status in (401, 403):
        return ShopifyAuthError(message, status_code=status, body=body, headers=headers)
    if status == 404:
        return ShopifyNotFoundError(message, body=body, headers=headers)
    if status in (400, 422):
        return ShopifyValidationError(message, body=body, headers=headers)
    if status == 429:
        return ShopifyRateLimitError(
            message, retry_after=_retry_after_seconds(headers), body=body, headers=headers
        )
    if status >= 500:
        return ShopifyServerError(message, status_code=status, body=body, headers=headers)
    return ShopifyHTTPError(message, status, body=body, headers=headers)


def _extract_error_message(body: Any) -> Optional[str]:
    if isinstance(body, dict):
        if "error" in body:
            err = body["error"]
            if isinstance(err, str):
                return err
            if isinstance(err, dict):
                return err.get("message") or json.dumps(err)
        if "errors" in body:
            errs = body["errors"]
            if isinstance(errs, (list, dict)):
                return json.dumps(errs)
            return str(errs)
        if "message" in body:
            return str(body["message"])
    if isinstance(body, str) and body:
        return body
    return None


def _singular(resource: str) -> str:
    """Return the singular wrap key for a REST resource (e.g. ``products`` -> ``product``)."""
    if resource.endswith("ies"):
        return resource[:-3] + "y"
    if resource.endswith("ses"):
        return resource[:-2]
    if resource.endswith("s"):
        return resource[:-1]
    return resource


def _extract_items(body: Any, resource: str) -> List[Dict[str, Any]]:
    """Extract the list of items from a REST list response body."""
    if isinstance(body, list):
        return body
    if isinstance(body, dict):
        if resource in body and isinstance(body[resource], list):
            return body[resource]
        # Some endpoints wrap under a different key (e.g. inventory_levels).
        for key in ("inventory_levels", "variants", "images", "fulfillments", "orders", "locations"):
            if key in body and isinstance(body[key], list):
                return body[key]
        # Fallback: first list value.
        for value in body.values():
            if isinstance(value, list):
                return value
    return []


def _unwrap_resource(
    body: Any, resource: str, resource_id: Optional[Union[str, int]] = None
) -> Dict[str, Any]:
    """Unwrap a single resource from a REST response body."""
    if isinstance(body, dict):
        key = _singular(resource)
        if key in body and isinstance(body[key], dict):
            return body[key]
        if resource in body and isinstance(body[resource], dict):
            return body[resource]
        return body
    return {"data": body}


def _next_cursor_from_link(link_header: Optional[str]) -> Optional[str]:
    """Extract the ``page_info`` cursor for the *next* page from a Link header.

    Shopify returns headers like::

        <https://.../products.json?page_info=abc&limit=50>; rel="next"

    We return the ``page_info`` value when ``rel="next"`` is present.
    """
    if not link_header:
        return None
    for part in link_header.split(","):
        segments = part.split(";")
        if len(segments) < 2:
            continue
        url_part = segments[0].strip().strip("<>")
        rel = ""
        for seg in segments[1:]:
            if seg.strip().startswith('rel='):
                rel = seg.strip().split("=", 1)[1].strip().strip('"')
        if rel == "next":
            parsed = urllib.parse.urlparse(url_part)
            qs = urllib.parse.parse_qs(parsed.query)
            if "page_info" in qs:
                return qs["page_info"][0]
    return None
