"""Cost tracking and performance monitoring / analytics.

This module provides two lightweight, dependency-free helpers:

* :class:`CostTracker` -- accumulates token usage and computes estimated spend
  per provider/model using a configurable price table.
* :class:`MetricsCollector` -- records latency and outcome samples and reports
  aggregate statistics (count, mean, p95, error rate).
"""
from __future__ import annotations

import threading
import time
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple

from lux.llm.base import CompletionResponse


# Default price table: (cost per 1M prompt tokens, cost per 1M completion tokens).
# Values are illustrative USD estimates; override via ``prices=``.
DEFAULT_PRICES: Dict[Tuple[str, str], Tuple[float, float]] = {
    ("openai", "gpt-4o"): (2.50, 10.00),
    ("openai", "gpt-4o-mini"): (0.15, 0.60),
    ("anthropic", "claude-3-5-sonnet-latest"): (3.00, 15.00),
    ("anthropic", "claude-3-haiku"): (0.25, 1.25),
    ("ollama", "llama3"): (0.0, 0.0),
}


@dataclass
class CostRecord:
    provider: str
    model: str
    prompt_tokens: int
    completion_tokens: int
    cost_usd: float


class CostTracker:
    """Thread-safe accumulator for token usage and estimated cost."""

    def __init__(self, prices: Optional[Dict[Tuple[str, str], Tuple[float, float]]] = None) -> None:
        self.prices = dict(prices if prices is not None else DEFAULT_PRICES)
        self._lock = threading.Lock()
        self.records: List[CostRecord] = []

    def estimate(self, provider: str, model: str, prompt_tokens: int, completion_tokens: int) -> float:
        prompt_price, completion_price = self.prices.get((provider, model), (0.0, 0.0))
        return (prompt_tokens / 1_000_000) * prompt_price + (completion_tokens / 1_000_000) * completion_price

    def record(self, response: CompletionResponse) -> CostRecord:
        cost = self.estimate(
            response.provider,
            response.model,
            response.usage.prompt_tokens,
            response.usage.completion_tokens,
        )
        rec = CostRecord(
            provider=response.provider,
            model=response.model,
            prompt_tokens=response.usage.prompt_tokens,
            completion_tokens=response.usage.completion_tokens,
            cost_usd=cost,
        )
        with self._lock:
            self.records.append(rec)
        return rec

    # -- aggregates -------------------------------------------------------- #
    @property
    def total_cost_usd(self) -> float:
        with self._lock:
            return sum(r.cost_usd for r in self.records)

    @property
    def total_tokens(self) -> int:
        with self._lock:
            return sum(r.prompt_tokens + r.completion_tokens for r in self.records)

    def by_provider(self) -> Dict[str, float]:
        result: Dict[str, float] = {}
        with self._lock:
            for r in self.records:
                result[r.provider] = result.get(r.provider, 0.0) + r.cost_usd
        return result

    def summary(self) -> Dict[str, object]:
        return {
            "requests": len(self.records),
            "total_tokens": self.total_tokens,
            "total_cost_usd": round(self.total_cost_usd, 6),
            "by_provider": {k: round(v, 6) for k, v in self.by_provider().items()},
        }


@dataclass
class LatencySample:
    provider: str
    model: str
    latency_ms: float
    success: bool


class MetricsCollector:
    """Records latency/outcome samples and computes aggregate statistics."""

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self.samples: List[LatencySample] = []

    def record(self, provider: str, model: str, latency_ms: float, success: bool) -> None:
        with self._lock:
            self.samples.append(LatencySample(provider, model, latency_ms, success))

    def record_response(self, response: CompletionResponse) -> None:
        self.record(response.provider, response.model, response.latency_ms, True)

    def timed(self, provider: str, model: str):
        """Context manager that records the elapsed wall-clock time."""
        return _TimedCall(self, provider, model)

    def _percentile(self, values: List[float], pct: float) -> float:
        if not values:
            return 0.0
        ordered = sorted(values)
        k = max(0, min(len(ordered) - 1, int(round((pct / 100.0) * (len(ordered) - 1)))))
        return ordered[k]

    def stats(self, provider: Optional[str] = None) -> Dict[str, object]:
        with self._lock:
            samples = [s for s in self.samples if provider is None or s.provider == provider]
        if not samples:
            return {"count": 0, "mean_ms": 0.0, "p95_ms": 0.0, "error_rate": 0.0}
        latencies = [s.latency_ms for s in samples]
        errors = sum(1 for s in samples if not s.success)
        return {
            "count": len(samples),
            "mean_ms": round(sum(latencies) / len(latencies), 3),
            "p95_ms": round(self._percentile(latencies, 95), 3),
            "error_rate": round(errors / len(samples), 4),
        }


class _TimedCall:
    """Context manager returned by :meth:`MetricsCollector.timed`."""

    def __init__(self, collector: MetricsCollector, provider: str, model: str) -> None:
        self.collector = collector
        self.provider = provider
        self.model = model
        self._start = 0.0
        self._success = True

    def __enter__(self) -> "_TimedCall":
        self._start = time.perf_counter()
        return self

    def __exit__(self, exc_type, exc, tb) -> bool:
        elapsed = (time.perf_counter() - self._start) * 1000.0
        self._success = exc_type is None
        self.collector.record(self.provider, self.model, elapsed, self._success)
        return False  # never suppress exceptions