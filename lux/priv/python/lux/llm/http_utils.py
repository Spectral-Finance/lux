"""Standard-library-only HTTP transport used by the providers.

We deliberately avoid third-party HTTP clients so the abstraction has no hard
runtime dependencies. The transport is a thin wrapper over :mod:`urllib` that:

* sends JSON request bodies,
* injects auth headers,
* parses JSON responses,
* maps HTTP status codes onto the provider error hierarchy, and
* supports line-oriented server-sent-event (SSE) streaming.

Tests monkeypatch :func:`http_post` / :func:`http_post_stream` (or the
lower-level :func:`_urlopen`) so no real network calls are made.
"""
from __future__ import annotations

import json
import urllib.error
import urllib.request
from typing import Any, Dict, Iterator, Mapping, Optional

from lux.llm.base import AuthError, ProviderError, RateLimitError, RetryableError


def _build_request(url: str, body: Dict[str, Any], headers: Mapping[str, str], method: str = "POST"):
    data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    for key, value in headers.items():
        req.add_header(key, value)
    return req


def _raise_for_status(status: int, payload: Any, provider: str) -> None:
    if status < 400:
        return
    message = f"{provider} request failed with HTTP {status}"
    if isinstance(payload, dict):
        err = payload.get("error")
        if isinstance(err, dict):
            message = f"{message}: {err.get('message', err)}"
        elif err:
            message = f"{message}: {err}"
    if status in (401, 403):
        raise AuthError(message, status_code=status, provider=provider)
    if status == 429:
        raise RateLimitError(message, status_code=status, provider=provider)
    if status in (500, 502, 503, 504, 408, 409):
        raise RetryableError(message, status_code=status, provider=provider)
    raise ProviderError(message, status_code=status, provider=provider)


def http_post(
    url: str,
    body: Dict[str, Any],
    headers: Optional[Mapping[str, str]] = None,
    *,
    timeout: float = 60.0,
    provider: str = "base",
) -> Dict[str, Any]:
    """POST ``body`` as JSON and return the parsed JSON response."""
    req = _build_request(url, body, headers or {})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:  # noqa: S310 (trusted endpoints)
            raw = resp.read().decode("utf-8")
            status = resp.getcode()
    except urllib.error.HTTPError as exc:  # non-2xx
        raw = exc.read().decode("utf-8", errors="replace")
        try:
            payload = json.loads(raw) if raw else {}
        except ValueError:
            payload = {"error": {"message": raw}}
        _raise_for_status(exc.code, payload, provider)
        raise  # unreachable, keeps type checkers happy
    except urllib.error.URLError as exc:
        raise RetryableError(f"{provider} connection error: {exc.reason}", provider=provider)

    if not raw:
        return {}
    try:
        return json.loads(raw)
    except ValueError as exc:
        raise ProviderError(f"{provider} returned invalid JSON: {exc}", provider=provider)


def http_post_stream(
    url: str,
    body: Dict[str, Any],
    headers: Optional[Mapping[str, str]] = None,
    *,
    timeout: float = 60.0,
    provider: str = "base",
) -> Iterator[str]:
    """POST ``body`` and yield raw SSE ``data:`` payload lines as strings."""
    req = _build_request(url, body, headers or {})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:  # noqa: S310
            status = resp.getcode()
            if status >= 400:
                raw = resp.read().decode("utf-8", errors="replace")
                try:
                    payload = json.loads(raw) if raw else {}
                except ValueError:
                    payload = {"error": {"message": raw}}
                _raise_for_status(status, payload, provider)
            for raw_line in resp:
                line = raw_line.decode("utf-8", errors="replace").strip()
                if not line or line.startswith(":"):
                    continue
                if line.startswith("data:"):
                    yield line[len("data:"):].strip()
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        try:
            payload = json.loads(raw) if raw else {}
        except ValueError:
            payload = {"error": {"message": raw}}
        _raise_for_status(exc.code, payload, provider)
    except urllib.error.URLError as exc:
        raise RetryableError(f"{provider} connection error: {exc.reason}", provider=provider)


def iter_sse_json(lines: Iterator[str]) -> Iterator[Dict[str, Any]]:
    """Parse SSE ``data:`` lines into JSON objects, skipping ``[DONE]``."""
    for line in lines:
        if line == "[DONE]":
            return
        if not line:
            continue
        try:
            yield json.loads(line)
        except ValueError:
            continue