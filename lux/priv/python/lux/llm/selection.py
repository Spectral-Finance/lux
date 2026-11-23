"""Automatic model selection logic.

The :class:`ModelSelector` chooses an appropriate model for a task based on a
set of registered :class:`ModelSpec` entries and simple heuristics (capability
requirements, cost/latency budgets, or an explicit preference). It is
intentionally lightweight and deterministic so it can run without network
access.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict, List, Optional


@dataclass
class ModelSpec:
    """Metadata describing a single model offered by a provider."""

    name: str
    provider: str
    # Relative cost score (higher == more expensive). Used for budget-aware pick.
    cost_tier: int = 1
    # Relative latency score (higher == slower).
    latency_tier: int = 1
    # Capability flags.
    supports_tools: bool = False
    supports_vision: bool = False
    context_window: int = 4096
    quality_tier: int = 1  # higher == smarter


# A small built-in catalogue so selection works without external data.
DEFAULT_CATALOGUE: List[ModelSpec] = [
    ModelSpec("gpt-4o", "openai", cost_tier=5, latency_tier=3, supports_tools=True, supports_vision=True, context_window=128000, quality_tier=5),
    ModelSpec("gpt-4o-mini", "openai", cost_tier=1, latency_tier=1, supports_tools=True, supports_vision=True, context_window=128000, quality_tier=3),
    ModelSpec("claude-3-5-sonnet-latest", "anthropic", cost_tier=4, latency_tier=3, supports_tools=True, supports_vision=True, context_window=200000, quality_tier=5),
    ModelSpec("claude-3-haiku", "anthropic", cost_tier=1, latency_tier=1, supports_tools=True, supports_vision=True, context_window=200000, quality_tier=3),
    ModelSpec("llama3", "ollama", cost_tier=0, latency_tier=2, supports_tools=False, context_window=8192, quality_tier=2),
]


class ModelSelector:
    """Selects a :class:`ModelSpec` from a catalogue based on requirements."""

    def __init__(self, catalogue: Optional[List[ModelSpec]] = None) -> None:
        self.catalogue: List[ModelSpec] = list(catalogue if catalogue is not None else DEFAULT_CATALOGUE)

    def register(self, spec: ModelSpec) -> None:
        self.catalogue.append(spec)

    def _candidates(
        self,
        provider: Optional[str],
        need_tools: bool,
        need_vision: bool,
        min_context: int,
    ) -> List[ModelSpec]:
        result = []
        for spec in self.catalogue:
            if provider and spec.provider != provider:
                continue
            if need_tools and not spec.supports_tools:
                continue
            if need_vision and not spec.supports_vision:
                continue
            if spec.context_window < min_context:
                continue
            result.append(spec)
        return result

    def select(
        self,
        *,
        provider: Optional[str] = None,
        need_tools: bool = False,
        need_vision: bool = False,
        min_context: int = 0,
        optimize_for: str = "quality",
        prefer: Optional[str] = None,
    ) -> ModelSpec:
        """Pick the best matching model.

        ``optimize_for`` is one of ``"quality"``, ``"cost"``, or ``"latency"``.
        ``prefer`` pins an exact model name if it is a valid candidate.
        """
        candidates = self._candidates(provider, need_tools, need_vision, min_context)
        if not candidates:
            raise ValueError(
                "no model matches the given constraints "
                f"(provider={provider}, tools={need_tools}, vision={need_vision}, ctx>={min_context})"
            )

        if prefer:
            for spec in candidates:
                if spec.name == prefer:
                    return spec
            raise ValueError(f"preferred model {prefer!r} does not satisfy constraints")

        if optimize_for == "cost":
            key = lambda s: (s.cost_tier, -s.quality_tier)
        elif optimize_for == "latency":
            key = lambda s: (s.latency_tier, -s.quality_tier)
        else:  # quality
            key = lambda s: (-s.quality_tier, s.cost_tier)
        return min(candidates, key=key)

    def select_model_name(self, **kwargs: object) -> str:
        """Convenience wrapper returning just the model name."""
        return self.select(**kwargs).name  # type: ignore[arg-type]