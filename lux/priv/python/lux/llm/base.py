"""Base provider interface, response types, and error hierarchy.

The :class:`LLMProvider` abstract base class is the universal interface every
concrete provider implements. It defines two required operations:

* :meth:`LLMProvider.complete` -- single-shot completion returning a
  :class:`CompletionResponse`.
* :meth:`LLMProvider.stream` -- streaming completion yielding
  :class:`StreamChunk` objects.

A :class:`BaseProvider` helper supplies production-grade retry logic (with
exponential backoff + jitter) that concrete providers inherit for free.
"""
from __future__ import annotations

import abc
import random
import time
from dataclasses import dataclass, field
from typing import Any, Dict, Iterator, List, Optional, Sequence

from lux.llm.message import Message, ToolCall


# --------------------------------------------------------------------------- #
# Error hierarchy
# --------------------------------------------------------------------------- #
class LLMError(Exception):
    """Base class for all LLM-layer errors."""


class ProviderError(LLMError):
    """A provider returned an error or an unrecoverable failure occurred."""

    def __init__(self, message: str, *, status_code: Optional[int] = None, provider: Optional[str] = None):
        super().__init__(message)
        self.status_code = status_code
        self.provider = provider


class RetryableError(ProviderError):
    """A transient error that is safe to retry (network blip, 5xx, ...)."""


class RateLimitError(RetryableError):
    """The provider signalled rate limiting (HTTP 429)."""

    def __init__(self, message: str = "rate limited", *, retry_after: Optional[float] = None, **kw: Any):
        super().__init__(message, **kw)
        self.retry_after = retry_after


class AuthError(ProviderError):
    """Authentication/authorization failed (HTTP 401/403). Not retryable."""


# --------------------------------------------------------------------------- #
# Response types
# --------------------------------------------------------------------------- #
@dataclass
class Usage:
    """Token usage accounting for a single request."""

    prompt_tokens: int = 0
    completion_tokens: int = 0

    @property
    def total_tokens(self) -> int:
        return self.prompt_tokens + self.completion_tokens

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "Usage":
        return cls(
            prompt_tokens=int(data.get("prompt_tokens", data.get("input_tokens", 0)) or 0),
            completion_tokens=int(data.get("completion_tokens", data.get("output_tokens", 0)) or 0),
        )


@dataclass
class CompletionResponse:
    """Normalised response returned by :meth:`LLMProvider.complete`."""

    text: str
    model: str
    provider: str
    usage: Usage = field(default_factory=Usage)
    tool_calls: List[ToolCall] = field(default_factory=list)
    finish_reason: Optional[str] = None
    raw: Dict[str, Any] = field(default_factory=dict)
    latency_ms: float = 0.0

    def __str__(self) -> str:  # pragma: no cover - convenience only
        return self.text


@dataclass
class StreamChunk:
    """A single incremental piece of a streamed completion."""

    text: str = ""
    model: str = ""
    provider: str = ""
    finish_reason: Optional[str] = None
    usage: Optional[Usage] = None
    done: bool = False


# --------------------------------------------------------------------------- #
# Provider interface
# --------------------------------------------------------------------------- #
class LLMProvider(abc.ABC):
    """Universal, provider-agnostic LLM interface.

    Parameters
    ----------
    model:
        Default model identifier to use when a call does not specify one.
    api_key:
        Credential for the provider (``None`` for local providers).
    base_url:
        Override the provider endpoint.
    timeout:
        Per-request timeout in seconds.
    max_retries:
        Number of retry attempts for transient failures.
    default_params:
        Extra parameters merged into every request body.
    """

    #: Short provider identifier, overridden by subclasses.
    name: str = "base"

    def __init__(
        self,
        model: str = "default",
        api_key: Optional[str] = None,
        base_url: Optional[str] = None,
        timeout: float = 60.0,
        max_retries: int = 3,
        default_params: Optional[Dict[str, Any]] = None,
        **extra: Any,
    ) -> None:
        self.model = model
        self.api_key = api_key
        self.base_url = base_url or self.default_base_url()
        self.timeout = timeout
        self.max_retries = max_retries
        self.default_params: Dict[str, Any] = dict(default_params or {})
        self.extra = extra

    # -- subclass hooks ---------------------------------------------------- #
    @staticmethod
    def default_base_url() -> str:
        """Return the provider's default endpoint."""
        return ""

    @abc.abstractmethod
    def complete(
        self,
        messages: Sequence[Message],
        *,
        model: Optional[str] = None,
        temperature: Optional[float] = None,
        max_tokens: Optional[int] = None,
        **params: Any,
    ) -> CompletionResponse:
        """Produce a single completion for ``messages``."""

    @abc.abstractmethod
    def stream(
        self,
        messages: Sequence[Message],
        *,
        model: Optional[str] = None,
        temperature: Optional[float] = None,
        max_tokens: Optional[int] = None,
        **params: Any,
    ) -> Iterator[StreamChunk]:
        """Yield :class:`StreamChunk` objects for ``messages``."""

    # -- shared helpers ---------------------------------------------------- #
    def _resolve_model(self, model: Optional[str]) -> str:
        return model or self.model

    def _merge_params(self, params: Dict[str, Any]) -> Dict[str, Any]:
        merged = dict(self.default_params)
        merged.update({k: v for k, v in params.items() if v is not None})
        return merged

    def __repr__(self) -> str:  # pragma: no cover - debugging aid
        return f"<{type(self).__name__} model={self.model!r} base_url={self.base_url!r}>"


class BaseProvider(LLMProvider):
    """Convenience base class adding retry/backoff around ``_do_complete``.

    Subclasses implement :meth:`_do_complete` (single attempt) and
    :meth:`_do_stream` (single streaming attempt). The public
    :meth:`complete` / :meth:`stream` methods wrap them with retry logic.
    """

    #: HTTP status codes that should trigger a retry.
    retryable_status = {408, 409, 425, 429, 500, 502, 503, 504}

    def _sleep_backoff(self, attempt: int, base: float = 0.5, cap: float = 8.0) -> None:
        delay = min(cap, base * (2 ** attempt))
        delay += random.uniform(0, delay * 0.1)  # jitter
        time.sleep(delay)

    def complete(self, messages: Sequence[Message], **params: Any) -> CompletionResponse:
        last_exc: Optional[Exception] = None
        for attempt in range(self.max_retries + 1):
            try:
                return self._do_complete(messages, **params)
            except (RetryableError, RateLimitError) as exc:
                last_exc = exc
                if attempt >= self.max_retries:
                    break
                retry_after = getattr(exc, "retry_after", None)
                if retry_after:
                    time.sleep(retry_after)
                else:
                    self._sleep_backoff(attempt)
            except ProviderError:
                raise
        assert last_exc is not None
        raise last_exc

    def stream(self, messages: Sequence[Message], **params: Any) -> Iterator[StreamChunk]:
        # Streaming retries only cover connection setup; once chunks flow we do
        # not attempt to replay the stream.
        last_exc: Optional[Exception] = None
        for attempt in range(self.max_retries + 1):
            try:
                yield from self._do_stream(messages, **params)
                return
            except (RetryableError, RateLimitError) as exc:
                last_exc = exc
                if attempt >= self.max_retries:
                    break
                self._sleep_backoff(attempt)
            except ProviderError:
                raise
        assert last_exc is not None
        raise last_exc

    # -- subclass hooks ---------------------------------------------------- #
    def _do_complete(self, messages: Sequence[Message], **params: Any) -> CompletionResponse:
        raise NotImplementedError

    def _do_stream(self, messages: Sequence[Message], **params: Any) -> Iterator[StreamChunk]:
        raise NotImplementedError