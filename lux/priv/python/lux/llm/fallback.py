"""Intelligent fallback handling across multiple providers.

A :class:`FallbackChain` wraps an ordered list of providers. It tries the
primary provider first; if that call raises a (retryable) provider error it
transparently advances to the next provider in the chain. This gives
applications resilience against a single provider outage or rate limit.
"""
from __future__ import annotations

from typing import Iterator, List, Optional, Sequence

from lux.llm.base import (
    CompletionResponse,
    LLMProvider,
    ProviderError,
    StreamChunk,
)
from lux.llm.message import Message


class AllProvidersFailedError(ProviderError):
    """Raised when every provider in a fallback chain has failed."""

    def __init__(self, provider_errors: Sequence[Exception]):
        self.provider_errors = list(provider_errors)
        detail = "; ".join(f"{type(e).__name__}: {e}" for e in self.provider_errors)
        super().__init__(f"all providers failed: {detail}")


class FallbackChain:
    """Ordered set of providers with automatic failover.

    Parameters
    ----------
    providers:
        Ordered providers; the first is the primary.
    retry_on:
        Exception types that trigger failover. Defaults to
        :class:`~lux.llm.base.ProviderError` (which includes rate-limit and
        retryable errors). Auth errors also subclass ``ProviderError`` and will
        therefore trigger failover, which is usually desirable.
    """

    def __init__(
        self,
        providers: Sequence[LLMProvider],
        *,
        retry_on: Optional[Sequence[type]] = None,
    ) -> None:
        if not providers:
            raise ValueError("FallbackChain requires at least one provider")
        self.providers: List[LLMProvider] = list(providers)
        self.retry_on = tuple(retry_on) if retry_on else (ProviderError,)

    @property
    def primary(self) -> LLMProvider:
        return self.providers[0]

    def complete(self, messages: Sequence[Message], **params: object) -> CompletionResponse:
        """Try each provider in order until one succeeds."""
        errors: List[Exception] = []
        for provider in self.providers:
            try:
                return provider.complete(messages, **params)  # type: ignore[arg-type]
            except self.retry_on as exc:  # type: ignore[misc]
                errors.append(exc)
                continue
        raise AllProvidersFailedError(errors)

    def stream(self, messages: Sequence[Message], **params: object) -> Iterator[StreamChunk]:
        """Stream from the first provider that yields at least one chunk.

        Because streaming is lazy, we attempt each provider and commit to the
        first one that produces output. If a provider fails before yielding we
        fall through to the next.
        """
        errors: List[Exception] = []
        for provider in self.providers:
            iterator = provider.stream(messages, **params)  # type: ignore[arg-type]
            try:
                first = next(iterator)
            except StopIteration:
                # Empty stream: treat as success with no output.
                return
            except self.retry_on as exc:  # type: ignore[misc]
                errors.append(exc)
                continue
            yield first
            yield from iterator
            return
        raise AllProvidersFailedError(errors)

    def __len__(self) -> int:
        return len(self.providers)

    def __repr__(self) -> str:  # pragma: no cover - debugging aid
        names = ", ".join(p.name for p in self.providers)
        return f"<FallbackChain providers=[{names}]>"