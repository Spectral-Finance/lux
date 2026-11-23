"""High-level orchestration client that ties the whole LLM layer together.

:class:`LLMClient` is the single ergonomic entry point most applications want.
It composes the lower-level building blocks:

* a :class:`~lux.llm.registry.ProviderRegistry` (provider management),
* a :class:`~lux.llm.selection.ModelSelector` (automatic model selection),
* an optional :class:`~lux.llm.fallback.FallbackChain` (intelligent failover),
* an optional :class:`~lux.llm.cache.SimpleCache` (response caching / optimisation),
* a :class:`~lux.llm.monitoring.CostTracker` and
  :class:`~lux.llm.monitoring.MetricsCollector` (cost + performance analytics).

It exposes the same :meth:`complete` / :meth:`stream` contract as a single
provider, but adds caching, cost accounting and latency metrics for free.
"""
from __future__ import annotations

import time
from typing import Any, Dict, Iterator, List, Optional, Sequence

from lux.llm.base import CompletionResponse, LLMProvider, StreamChunk
from lux.llm.cache import SimpleCache, make_cache_key
from lux.llm.config import LLMConfig, load_config
from lux.llm.fallback import FallbackChain
from lux.llm.message import Message
from lux.llm.monitoring import CostTracker, MetricsCollector
from lux.llm.registry import ProviderRegistry
from lux.llm.selection import ModelSelector, ModelSpec

__all__ = ["LLMClient"]


class LLMClient:
    """Provider-agnostic façade with caching, cost tracking and metrics.

    Parameters
    ----------
    config:
        Resolved :class:`~lux.llm.config.LLMConfig` (defaults to env config).
    registry:
        Optional pre-built registry (mainly for testing / custom providers).
    providers:
        Optional explicit provider list. When given, a
        :class:`~lux.llm.fallback.FallbackChain` is built over them so calls
        automatically fail over.
    cache:
        Optional :class:`~lux.llm.cache.SimpleCache`. Caching is disabled when
        omitted.
    cost_tracker / metrics:
        Injectable trackers (fresh instances are created by default).
    selector:
        Optional :class:`~lux.llm.selection.ModelSelector`.
    """

    def __init__(
        self,
        *,
        config: Optional[LLMConfig] = None,
        registry: Optional[ProviderRegistry] = None,
        providers: Optional[Sequence[LLMProvider]] = None,
        cache: Optional[SimpleCache] = None,
        cost_tracker: Optional[CostTracker] = None,
        metrics: Optional[MetricsCollector] = None,
        selector: Optional[ModelSelector] = None,
    ) -> None:
        self.config = config or load_config()
        self.registry = registry or ProviderRegistry(self.config)
        self.selector = selector or ModelSelector()
        self.cache = cache
        self.cost_tracker = cost_tracker or CostTracker()
        self.metrics = metrics or MetricsCollector()
        self._providers: Optional[List[LLMProvider]] = (
            list(providers) if providers else None
        )
        self._fallback: Optional[FallbackChain] = (
            FallbackChain(providers) if providers and len(providers) > 1 else None
        )

    # -- constructors ------------------------------------------------------ #
    @classmethod
    def from_env(cls, **kwargs: Any) -> "LLMClient":
        """Build a client from environment variables."""
        return cls(config=load_config(), **kwargs)

    # -- provider resolution ---------------------------------------------- #
    def provider(self, name: Optional[str] = None, **overrides: Any) -> LLMProvider:
        """Return the provider used for a call (registry lookup)."""
        if self._providers is not None:
            if name is None:
                return self._providers[0]
            for p in self._providers:
                if p.name == name:
                    return p
            raise KeyError(f"provider {name!r} not in configured provider list")
        return self.registry.get(name, **overrides)

    def _target(self, name: Optional[str]) -> Any:
        if self._fallback is not None:
            return self._fallback
        return self.provider(name)

    # -- core API ---------------------------------------------------------- #
    def complete(
        self,
        messages: Sequence[Message],
        *,
        provider: Optional[str] = None,
        model: Optional[str] = None,
        use_cache: bool = True,
        **params: Any,
    ) -> CompletionResponse:
        """Produce a completion, recording cost + latency and using the cache."""
        target = self._target(provider)

        cache_key: Optional[str] = None
        if use_cache and self.cache is not None and self._fallback is None:
            resolved_model = model or getattr(target, "model", "")
            cache_key = make_cache_key(
                getattr(target, "name", "provider"), resolved_model, messages, params
            )
            cached = self.cache.get(cache_key)
            if cached is not None:
                return cached

        start = time.perf_counter()
        response = target.complete(messages, model=model, **params)
        response.latency_ms = (time.perf_counter() - start) * 1000.0

        self.cost_tracker.record(response)
        self.metrics.record_response(response)
        if cache_key is not None and self.cache is not None:
            self.cache.set(cache_key, response)
        return response

    def stream(
        self,
        messages: Sequence[Message],
        *,
        provider: Optional[str] = None,
        model: Optional[str] = None,
        **params: Any,
    ) -> Iterator[StreamChunk]:
        """Stream a completion from the resolved provider / fallback chain."""
        target = self._target(provider)
        return target.stream(messages, model=model, **params)

    # -- selection --------------------------------------------------------- #
    def select(self, **kwargs: Any) -> ModelSpec:
        """Choose a :class:`~lux.llm.selection.ModelSpec` for a task."""
        return self.selector.select(**kwargs)

    def summary(self) -> Dict[str, Any]:
        """Return a combined cost + performance snapshot."""
        return {
            "cost": self.cost_tracker.summary(),
            "metrics": self.metrics.stats(),
            "cache": self.cache.stats() if self.cache is not None else None,
        }

    def __repr__(self) -> str:  # pragma: no cover - debugging aid
        return f"<LLMClient providers={self.registry.available()!r}>"